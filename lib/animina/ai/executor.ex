defmodule Animina.AI.Executor do
  @moduledoc """
  Stateless module that executes a single AI job.

  Called by the Scheduler via Task.Supervisor. Handles the full lifecycle:
  1. Resolve job type module
  2. Prepare input and build prompt
  3. Select model (with adaptive downgrade for vision jobs)
  4. Build instance filter for job-type-aware routing
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
  alias Animina.AI.Semaphore
  alias Animina.FeatureFlags

  # Smallest vision model — used when CPU instance handles vision overflow
  @cpu_vision_model "qwen3-vl:2b"

  @doc """
  Executes a single AI job. Called from Task.Supervisor.
  """
  def run(%AI.Job{} = job) do
    module = AI.job_type_module(job.job_type)

    if module do
      execute_with_module(job, module)
    else
      AI.mark_failed(job, "Unknown job type: #{job.job_type}")
      :error
    end
  end

  defp execute_with_module(job, module) do
    # Mark as running
    case AI.mark_running(job) do
      {:ok, job} ->
        do_execute(job, module)

      {:error, reason} ->
        Logger.error("AI.Executor: Failed to mark job #{job.id} as running: #{inspect(reason)}")
        :error
    end
  end

  defp do_execute(job, module) do
    # Prepare input
    case module.prepare_input(job.params) do
      {:ok, input_opts} ->
        execute_with_input(job, module, input_opts)

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

  defp execute_with_input(job, module, input_opts) do
    prompt = module.build_prompt(job.params)
    model_family = module.model_family()
    model = select_model(job, module)
    {instance_filter, model} = build_instance_filter(model_family, model)

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
        AI.mark_failed(job, "Semaphore timeout", %{prompt: prompt, model: model})
        :retry
    end
  end

  defp run_completion(job, module, model, prompt, input_opts, instance_filter) do
    completion_opts =
      [model: model, prompt: prompt, instance_filter: instance_filter] ++
        Keyword.take(input_opts, [:images, :target_server])

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

  @doc false
  def build_instance_filter(:vision, model) do
    # Vision jobs prefer GPU instances (sorted by fastest avg_duration)
    # If all GPU instances are unhealthy, Client falls back to all instances
    # When a CPU instance handles a vision job, force smallest model
    filter = fn instance ->
      tags = Map.get(instance, :tags, [])

      if "gpu" in tags do
        true
      else
        # CPU instance — will be included only if GPU filter returns empty
        false
      end
    end

    # Wrap to handle CPU fallback: if the chosen instance is CPU, override model
    # This is handled at the Client level — if filter returns empty, all instances are tried
    # We need a different approach: use a two-phase filter
    gpu_instances = get_gpu_instance_count()

    if gpu_instances > 0 do
      {filter, model}
    else
      # No GPU instances configured at all — use smallest model on CPU
      {nil, @cpu_vision_model}
    end
  end

  def build_instance_filter(:text, model) do
    # Text jobs prefer CPU instances (they handle text well, saves GPU for vision)
    filter = fn instance ->
      tags = Map.get(instance, :tags, [])
      "cpu" in tags
    end

    cpu_count = get_cpu_instance_count()

    if cpu_count > 0 do
      {filter, model}
    else
      # No CPU instances — run text on any instance
      {nil, model}
    end
  end

  def build_instance_filter(_family, model) do
    {nil, model}
  end

  defp get_gpu_instance_count do
    Client.ollama_instances()
    |> Enum.count(fn inst -> "gpu" in Map.get(inst, :tags, []) end)
  end

  defp get_cpu_instance_count do
    Client.ollama_instances()
    |> Enum.count(fn inst -> "cpu" in Map.get(inst, :tags, []) end)
  end

  defp select_vision_model(_module) do
    # GPUs are fast enough for the best model — always use tier1 (8b).
    # CPU fallback uses the smallest model, handled by build_instance_filter.
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
