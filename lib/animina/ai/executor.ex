defmodule Animina.AI.Executor do
  @moduledoc """
  Stateless module that executes a single AI job.

  Called by the Scheduler via Task.Supervisor. Handles the full lifecycle:
  1. Resolve job type module
  2. Prepare input and build prompt
  3. Select model (with adaptive downgrade for vision jobs)
  4. Acquire semaphore slot
  5. Call Client.completion, measure duration
  6. On success: call handle_result, mark completed
  7. On failure: schedule retry with backoff or mark failed
  8. Report duration to Autoscaler
  9. Release semaphore
  """

  require Logger

  alias Animina.AI
  alias Animina.AI.Autoscaler
  alias Animina.AI.Client
  alias Animina.AI.Semaphore
  alias Animina.FeatureFlags

  @doc """
  Executes a single AI job. Called from Task.Supervisor.
  """
  def run(%AI.Job{} = job) do
    module = AI.job_type_module(job.job_type)

    unless module do
      AI.mark_failed(job, "Unknown job type: #{job.job_type}")
      :error
    else
      execute_with_module(job, module)
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
        AI.mark_failed(job, error_msg)
        Logger.warning("AI.Executor: #{error_msg} for job #{job.id}")
        :error
    end
  end

  defp execute_with_input(job, module, input_opts) do
    prompt = module.build_prompt(job.params)
    model = select_model(job, module)

    # Apply configured delay for UX testing
    FeatureFlags.apply_delay(:photo_ollama_check)

    timeout = FeatureFlags.ollama_semaphore_timeout()

    case Semaphore.acquire(timeout) do
      :ok ->
        try do
          run_completion(job, module, model, prompt, input_opts)
        after
          Semaphore.release()
        end

      {:error, :timeout} ->
        Logger.debug("AI.Executor: Semaphore busy, rescheduling job #{job.id}")
        AI.mark_failed(job, "Semaphore timeout", %{prompt: prompt, model: model})
        :retry
    end
  end

  defp run_completion(job, module, model, prompt, input_opts) do
    completion_opts =
      [model: model, prompt: prompt] ++ Keyword.take(input_opts, [:images, :target_server])

    {duration_us, result} = :timer.tc(fn -> Client.completion(completion_opts) end)
    duration_ms = div(duration_us, 1000)

    # Report to autoscaler
    Autoscaler.report_duration(duration_ms)

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
        AI.mark_completed(job, Map.merge(attrs, %{result: result_map}))
        Logger.info("AI job #{job.id} (#{job.job_type}) completed in #{attrs.duration_ms}ms")
        :ok

      {:error, reason} ->
        error_msg = "Result handling failed: #{inspect(reason)}"
        AI.mark_failed(job, error_msg, attrs)
        Logger.warning("AI.Executor: #{error_msg} for job #{job.id}")
        :error
    end
  end

  defp handle_failure(job, reason, attrs) do
    error_msg = inspect(reason)
    AI.mark_failed(job, error_msg, attrs)
    Logger.warning("AI.Executor: Job #{job.id} failed: #{error_msg}")
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

  defp select_vision_model(module) do
    if FeatureFlags.enabled?(:ollama_adaptive_model) do
      # Use queue-pressure-based adaptive selection
      pending_count = AI.count_jobs(filter_status: "pending")

      downgrade_tier3 = FeatureFlags.ollama_downgrade_tier3_threshold()
      downgrade_tier2 = FeatureFlags.ollama_downgrade_tier2_threshold()
      upgrade = FeatureFlags.ollama_upgrade_threshold()

      cond do
        pending_count > downgrade_tier3 -> FeatureFlags.ollama_model_tier3()
        pending_count > downgrade_tier2 -> FeatureFlags.ollama_model_tier2()
        pending_count <= upgrade -> FeatureFlags.ollama_model_tier1()
        true -> FeatureFlags.ollama_model_tier2()
      end
    else
      module.default_model()
    end
  rescue
    _ -> module.default_model()
  end
end
