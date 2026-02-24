defmodule Animina.AI.Executor do
  @moduledoc """
  Stateless module that executes a single AI job.

  Called by the Scheduler via Task.Supervisor. Handles the full lifecycle:
  1. Resolve job type module
  2. Prepare input and build prompt
  3. Select model (with adaptive downgrade for vision jobs)
  4. Resolve pre-computed route to instance filter
  5. Acquire semaphore slot
  6. Call Client.completion, measure duration
  7. On success: call handle_result, mark completed
  8. On failure: schedule retry with backoff or mark failed
  9. Release semaphore
  """

  require Logger

  alias Animina.ActivityLog
  alias Animina.AI
  alias Animina.AI.Client
  alias Animina.AI.PerformanceStats
  alias Animina.AI.Semaphore
  alias Animina.FeatureFlags

  # Smallest vision model — used when CPU instance handles vision overflow
  @cpu_vision_model "qwen3-vl:2b"

  # When estimated times are within this tolerance, prefer CPU to keep throughput up
  @cpu_tolerance 1.1

  @doc """
  Executes a single AI job with a pre-computed route.
  Called from Task.Supervisor when the Scheduler has already decided GPU vs CPU.
  """
  def run(%AI.Job{} = job, route) do
    case AI.job_type_module(job.job_type) do
      {:ok, module} ->
        execute_with_module(job, module, route)

      :error ->
        AI.mark_failed(job, "Unknown job type: #{job.job_type}")
        :error
    end
  end

  @doc """
  Pre-computes the routing decision for a job given its position in the GPU queue.
  Called by the Scheduler sequentially to avoid the race condition of concurrent
  Tasks all querying count_deferred_jobs() simultaneously.

  Returns:
    - `{:dispatch, route, new_gpu_depth}` — dispatch with this route
    - `{:skip_for_gpu, new_gpu_depth}` — skip, job waits in queue for GPU
  """
  def pre_route(job, module, gpu_queue_depth) do
    model_family = module.model_family()
    model = select_model(job, module)
    gpu_count = get_gpu_instance_count()
    cpu_count = get_cpu_instance_count()

    cond do
      gpu_count == 0 ->
        {:dispatch, {:run_any, maybe_downgrade_vision(model_family, model)}, gpu_queue_depth}

      not PerformanceStats.gpu_busy?() ->
        {:dispatch, {:run_gpu, model}, gpu_queue_depth + 1}

      cpu_count == 0 ->
        {:dispatch, {:run_gpu, model}, gpu_queue_depth + 1}

      true ->
        position_aware_route(job.job_type, model_family, model, gpu_queue_depth)
    end
  end

  @doc """
  Forces a job to CPU when the GPU queue cap has been reached.
  Downgrades vision models to the smallest CPU-compatible variant.

  Called by the Scheduler when `gpu_queued >= max_gpu_queue`.
  """
  def force_cpu(job, model_family, model, gpu_queue_depth) do
    Logger.info("AI routing: GPU queue full, forcing job #{job.job_type} to CPU")

    {:dispatch, {:run_cpu, maybe_downgrade_vision(model_family, model)}, gpu_queue_depth}
  end

  defp position_aware_route(job_type, model_family, model, gpu_queue_depth) do
    gpu_avg = PerformanceStats.avg_duration_ms("gpu", job_type)
    cpu_avg = PerformanceStats.avg_duration_ms("cpu", job_type)

    case {gpu_avg, cpu_avg} do
      {nil, nil} ->
        # No history — coin flip, always dispatch to build stats
        if :rand.uniform() > 0.5 do
          {:dispatch, {:run_cpu, maybe_downgrade_vision(model_family, model)}, gpu_queue_depth}
        else
          {:dispatch, {:run_gpu, model}, gpu_queue_depth + 1}
        end

      {_gpu, nil} ->
        # Only GPU data — skip, wait for GPU
        {:skip_for_gpu, gpu_queue_depth + 1}

      {nil, _cpu} ->
        # Only CPU data — use CPU
        {:dispatch, {:run_cpu, maybe_downgrade_vision(model_family, model)}, gpu_queue_depth}

      {gpu_job_avg, cpu_job_avg} ->
        compare_with_queue_position(
          job_type,
          model_family,
          model,
          gpu_job_avg,
          cpu_job_avg,
          gpu_queue_depth
        )
    end
  end

  defp compare_with_queue_position(
         job_type,
         model_family,
         model,
         gpu_job_avg,
         cpu_job_avg,
         gpu_queue_depth
       ) do
    gpu_remaining = compute_gpu_remaining()
    gpu_queue_wait = gpu_queue_depth * gpu_job_avg
    gpu_total = gpu_remaining + gpu_queue_wait + gpu_job_avg
    cpu_total = cpu_job_avg

    if cpu_total < gpu_total * @cpu_tolerance do
      Logger.debug(
        "AI routing: #{job_type} pos=#{gpu_queue_depth} — CPU #{round(cpu_total)}ms < GPU #{round(gpu_total)}ms → CPU"
      )

      {:dispatch, {:run_cpu, maybe_downgrade_vision(model_family, model)}, gpu_queue_depth}
    else
      Logger.debug(
        "AI routing: #{job_type} pos=#{gpu_queue_depth} — GPU #{round(gpu_total)}ms < CPU #{round(cpu_total)}ms → skip for GPU"
      )

      {:skip_for_gpu, gpu_queue_depth + 1}
    end
  end

  defp execute_with_module(job, module, route) do
    # Mark as running
    case AI.mark_running(job) do
      {:ok, job} ->
        do_execute(job, module, route)

      {:error, reason} ->
        Logger.error("AI.Executor: Failed to mark job #{job.id} as running: #{inspect(reason)}")
        :error
    end
  end

  defp do_execute(job, module, route) do
    # Prepare input
    case module.prepare_input(job.params) do
      {:ok, input_opts} ->
        execute_with_input(job, module, input_opts, route)

      {:error, reason} ->
        error_msg = "Input preparation failed: #{inspect(reason)}"

        if terminal_input_error?(reason) do
          AI.cancel_with_error(job.id, error_msg)
          Logger.info("AI.Executor: Cancelled job #{job.id} (terminal): #{error_msg}")
        else
          AI.mark_failed(job, error_msg)
          Logger.warning("AI.Executor: #{error_msg} for job #{job.id}")
        end

        :error
    end
  end

  defp execute_with_input(job, module, input_opts, route) do
    prompt =
      try do
        module.build_prompt(job.params)
      rescue
        e -> {:error, Exception.message(e)}
      end

    case prompt do
      {:error, msg} ->
        AI.cancel_with_error(job.id, "build_prompt failed: #{msg}")
        Logger.warning("AI.Executor: build_prompt failed for job #{job.id}: #{msg}")
        :error

      prompt ->
        execute_with_prompt(job, module, input_opts, prompt, route)
    end
  end

  defp execute_with_prompt(job, module, input_opts, prompt, route) do
    {instance_filter, model} = resolve_route(route)

    # Apply configured delay for UX testing
    FeatureFlags.apply_delay(:photo_ollama_check)

    timeout = FeatureFlags.ollama_semaphore_timeout()

    case Semaphore.acquire(timeout) do
      :ok ->
        try do
          run_completion(job, module, model, prompt, input_opts, instance_filter)
        after
          Semaphore.release()
        end

      {:error, :timeout} ->
        Logger.debug("AI.Executor: Semaphore busy, rescheduling job #{job.id}")
        AI.reschedule_running_job(job.id)
        :retry
    end
  end

  defp resolve_route({:run_gpu, model}), do: {gpu_filter(), model}
  defp resolve_route({:run_cpu, model}), do: {cpu_filter(), model}
  defp resolve_route({:run_any, model}), do: {nil, model}

  defp run_completion(job, module, model, prompt, input_opts, instance_filter) do
    completion_opts =
      [model: model, prompt: prompt, instance_filter: instance_filter] ++
        Keyword.take(input_opts, [:images, :target_server, :api_opts])

    {duration_us, result} = :timer.tc(fn -> Client.completion(completion_opts) end)
    duration_ms = div(duration_us, 1000)

    case result do
      {:ok, %{"response" => response}, server_url} ->
        handle_success(job, module, response, %{
          model: model,
          server_url: server_url,
          prompt: prompt,
          raw_response: response,
          duration_ms: duration_ms
        })

      {:error, reason} ->
        handle_failure(job, reason, %{
          model: model,
          prompt: prompt,
          duration_ms: duration_ms
        })
    end
  end

  defp handle_success(job, module, response, attrs) do
    case module.handle_result(job, response) do
      {:ok, result_map} ->
        case AI.mark_completed(job, Map.merge(attrs, %{result: result_map})) do
          {:ok, _} ->
            Logger.info("AI job #{job.id} (#{job.job_type}) completed in #{attrs.duration_ms}ms")

            ActivityLog.log(
              "system",
              "ollama_processed",
              "AI job #{job.job_type} completed in #{format_ms(attrs.duration_ms)}",
              actor_id: job.requester_id,
              metadata:
                %{
                  "job_id" => job.id,
                  "job_type" => job.job_type,
                  "duration_ms" => attrs.duration_ms,
                  "model" => attrs.model
                }
                |> maybe_put_photo_id(job)
            )

            :ok

          {:error, :job_not_running} ->
            Logger.info(
              "AI.Executor: Job #{job.id} was cancelled/restarted while running; result discarded"
            )

            :ok
        end

      {:error, reason} ->
        error_msg = "Result handling failed: #{inspect(reason)}"

        case AI.mark_failed(job, error_msg, attrs) do
          {:error, :job_not_running} ->
            Logger.info(
              "AI.Executor: Job #{job.id} was cancelled/restarted while running; failure discarded"
            )

          _ ->
            Logger.warning("AI.Executor: #{error_msg} for job #{job.id}")
        end

        :error
    end
  end

  defp handle_failure(job, reason, attrs) do
    error_msg = inspect(reason)

    case AI.mark_failed(job, error_msg, attrs) do
      {:error, :job_not_running} ->
        Logger.info(
          "AI.Executor: Job #{job.id} was cancelled/restarted while running; failure discarded"
        )

      _ ->
        Logger.warning("AI.Executor: Job #{job.id} failed: #{error_msg}")
    end

    :error
  end

  defp select_model(job, module) do
    # Use job-specific model override if set, otherwise adaptive selection for vision
    cond do
      job.model ->
        job.model

      module.model_family() == :vision ->
        select_vision_model(module)

      true ->
        module.default_model()
    end
  end

  defp terminal_input_error?(:photo_not_found), do: true
  defp terminal_input_error?({:thumbnail_read_failed, :enoent}), do: true
  defp terminal_input_error?(_), do: false

  defp maybe_downgrade_vision(:vision, _model), do: @cpu_vision_model
  defp maybe_downgrade_vision(_family, model), do: model

  defp compute_gpu_remaining do
    gpu_overall_avg = PerformanceStats.avg_duration_ms_all("gpu")
    elapsed = PerformanceStats.oldest_running_elapsed_ms()

    case {gpu_overall_avg, elapsed} do
      {nil, _} -> 0
      {_, nil} -> 0
      {avg, el} -> max(0, avg - el)
    end
  end

  defp gpu_filter, do: fn instance -> "gpu" in Map.get(instance, :tags, []) end
  defp cpu_filter, do: fn instance -> "cpu" in Map.get(instance, :tags, []) end

  @doc """
  Returns the number of GPU-tagged Ollama instances.
  """
  def get_gpu_instance_count do
    Client.ollama_instances()
    |> Enum.count(fn inst -> "gpu" in Map.get(inst, :tags, []) end)
  end

  defp get_cpu_instance_count do
    Client.ollama_instances()
    |> Enum.count(fn inst -> "cpu" in Map.get(inst, :tags, []) end)
  end

  defp select_vision_model(_module) do
    # GPUs are fast enough for the best model — always use tier1 (8b).
    # CPU fallback uses the smallest model, handled by maybe_downgrade_vision.
    FeatureFlags.ollama_model_tier1()
  rescue
    _ -> "qwen3-vl:8b"
  end

  defp maybe_put_photo_id(metadata, %{params: %{"photo_id" => photo_id}})
       when is_binary(photo_id),
       do: Map.put(metadata, "photo_id", photo_id)

  defp maybe_put_photo_id(metadata, _job), do: metadata

  defp format_ms(ms) when is_integer(ms) do
    ms
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0.")
    |> String.reverse()
    |> Kernel.<>("ms")
  end
end
