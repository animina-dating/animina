defmodule Animina.AI.Queue do
  @moduledoc """
  Single GenServer replacing the old Scheduler + Executor + Semaphore.

  Manages a list of Ollama instances, each either idle or busy with a job.
  Dispatches jobs to instances using preferred-family routing:
  - Both vision and text jobs prefer GPU for speed
  - Falls back to CPU instances when GPU is busy
  - One job per instance — natural concurrency bound

  Wakes on:
  - `:tick` every 5s — maintenance (cancel expired, reset stuck) + dispatch
  - `"ai:new_job"` PubSub — immediate dispatch
  - `{:job_done, url, job_id}` — mark instance free + dispatch
  """

  use GenServer

  require Logger

  alias Animina.AI
  alias Animina.AI.Client
  alias Animina.Wingman.Preheater

  @tick_interval 5_000
  @stuck_timeout 180

  # Fetch more jobs than free instances so routing can skip mismatches
  @dispatch_multiplier 3

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the current status of all instances.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    instances =
      Client.parse_instances()
      |> Enum.map(fn inst ->
        %{
          url: inst.url,
          timeout: Map.get(inst, :timeout, 120_000),
          tags: Map.get(inst, :tags, ["gpu"]),
          busy: nil
        }
      end)

    # Subscribe to new job notifications
    Phoenix.PubSub.subscribe(Animina.PubSub, "ai:new_job")

    # Reset stuck running jobs from previous crash
    AI.reset_running_jobs()

    # Schedule first tick
    Process.send_after(self(), :tick, @tick_interval)

    # Warmup after 2s delay
    Process.send_after(self(), :warmup, 2_000)

    # Preheat wingman hints after warmup completes (~30s delay)
    Process.send_after(self(), :preheat, 30_000)

    Logger.info("AI Queue started with #{length(instances)} instance(s)")
    {:ok, %{instances: instances, task_refs: %{}}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    instance_info =
      Enum.map(state.instances, fn inst ->
        %{
          url: inst.url,
          tags: inst.tags,
          busy: inst.busy
        }
      end)

    {:reply, instance_info, state}
  end

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, @tick_interval)

    if AI.queue_paused?() do
      {:noreply, state}
    else
      # Maintenance
      AI.cancel_expired_jobs()
      AI.reset_stuck_jobs(@stuck_timeout)

      # Dispatch
      {:noreply, dispatch(state)}
    end
  end

  # PubSub: new job enqueued
  @impl true
  def handle_info(:new_job, state) do
    if AI.queue_paused?() do
      {:noreply, state}
    else
      {:noreply, dispatch(state)}
    end
  end

  # Task completed successfully
  @impl true
  def handle_info({:job_done, url, _job_id}, state) do
    state = update_instance(state, url, nil)
    {:noreply, dispatch(state)}
  end

  # Task.Supervisor child finished (normal exit) — clean up tracked ref
  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, remove_task_ref(state, ref)}
  end

  # Task.Supervisor child crashed — free the instance so it doesn't stay busy forever
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) when reason != :normal do
    Logger.warning("AI Queue: task process crashed: #{inspect(reason)}")

    case Map.get(state.task_refs, ref) do
      nil ->
        {:noreply, state}

      url ->
        state = state |> update_instance(url, nil) |> remove_task_ref(ref)
        {:noreply, dispatch(state)}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, :normal}, state) do
    {:noreply, remove_task_ref(state, ref)}
  end

  @impl true
  def handle_info(:warmup, state) do
    warmup_instances(state.instances)
    {:noreply, state}
  end

  @impl true
  def handle_info(:preheat, state) do
    Task.Supervisor.start_child(Animina.AI.TaskSupervisor, fn ->
      Preheater.run()
    end)

    {:noreply, state}
  end

  # --- Dispatch ---

  defp dispatch(state) do
    free_instances = Enum.filter(state.instances, fn inst -> inst.busy == nil end)

    if free_instances == [] do
      state
    else
      jobs = AI.list_runnable_jobs(length(free_instances) * @dispatch_multiplier)
      assign_jobs(state, free_instances, jobs)
    end
  end

  defp assign_jobs(state, _free_instances, []), do: state

  defp assign_jobs(state, [], _jobs), do: state

  defp assign_jobs(state, free_instances, [job | rest_jobs]) do
    case pick_instance(free_instances, job) do
      nil ->
        # No suitable instance, skip this job for now
        assign_jobs(state, free_instances, rest_jobs)

      instance ->
        # Mark running in DB
        case AI.mark_running(job) do
          {:ok, running_job} ->
            state = start_job(state, instance.url, running_job)
            state = update_instance(state, instance.url, running_job.id)
            remaining_free = Enum.reject(free_instances, fn i -> i.url == instance.url end)
            assign_jobs(state, remaining_free, rest_jobs)

          {:error, _} ->
            # Job may have been cancelled, try next
            assign_jobs(state, free_instances, rest_jobs)
        end
    end
  end

  defp pick_instance(free_instances, job) do
    case AI.job_type_module(job.job_type) do
      {:ok, module} ->
        family = module.model_family()
        preferred = preferred_tags(family)

        # Try preferred instances first, then any
        Enum.find(free_instances, fn inst ->
          Enum.any?(preferred, &(&1 in inst.tags))
        end) || List.first(free_instances)

      :error ->
        List.first(free_instances)
    end
  end

  defp preferred_tags(:vision), do: ["gpu"]
  defp preferred_tags(:text), do: ["gpu"]

  # --- Job Execution ---

  defp start_job(state, url, job) do
    queue_pid = self()
    timeout = get_instance_timeout(state, url)

    {:ok, pid} =
      Task.Supervisor.start_child(Animina.AI.TaskSupervisor, fn ->
        execute_job(url, job, timeout, queue_pid)
      end)

    ref = Process.monitor(pid)
    track_task_ref(state, ref, url)
  end

  defp execute_job(url, job, timeout, queue_pid) do
    case AI.job_type_module(job.job_type) do
      {:ok, module} ->
        do_execute(url, job, timeout, module, queue_pid)

      :error ->
        AI.mark_failed(job, "Unknown job type: #{job.job_type}")
        send(queue_pid, {:job_done, url, job.id})
    end
  end

  defp do_execute(url, job, timeout, module, queue_pid) do
    model = job.model || module.model()
    prompt = module.build_prompt(job.params)

    case module.prepare_input(job.params) do
      {:ok, input_opts} ->
        client_opts =
          [url: url, model: model, prompt: prompt, timeout: timeout] ++ input_opts

        case Client.completion(client_opts) do
          {:ok, response_text, duration_ms} ->
            handle_success(job, module, response_text, model, url, prompt, duration_ms, queue_pid)

          {:error, reason} ->
            handle_failure(job, reason, model, url, prompt, queue_pid)
        end

      {:error, reason} ->
        # Input preparation failed (e.g., photo deleted) — cancel job
        AI.cancel_with_error(job.id, "Input preparation failed: #{inspect(reason)}")
        broadcast_result(job.id, {:error, reason})
        send(queue_pid, {:job_done, url, job.id})
    end
  end

  defp handle_success(job, module, response_text, model, url, prompt, duration_ms, queue_pid) do
    case module.handle_result(job, response_text) do
      {:ok, result} ->
        AI.mark_completed(job, %{
          result: result,
          model: model,
          server_url: url,
          prompt: prompt,
          raw_response: response_text,
          duration_ms: duration_ms
        })

        broadcast_result(job.id, {:ok, result})

      {:error, reason} ->
        AI.mark_failed(job, "Result handling failed: #{inspect(reason)}", %{
          model: model,
          server_url: url,
          prompt: prompt,
          raw_response: response_text,
          duration_ms: duration_ms
        })

        broadcast_result(job.id, {:error, reason})
    end

    send(queue_pid, {:job_done, url, job.id})
  end

  defp handle_failure(job, reason, model, url, prompt, queue_pid) do
    AI.mark_failed(job, inspect(reason), %{
      model: model,
      server_url: url,
      prompt: prompt
    })

    broadcast_result(job.id, {:error, reason})
    send(queue_pid, {:job_done, url, job.id})
  end

  defp broadcast_result(job_id, result) do
    topic = "ai:result:#{job_id}"
    Phoenix.PubSub.broadcast(Animina.PubSub, topic, {:ai_result, topic, result})
  end

  # --- Instance Management ---

  defp update_instance(state, url, busy_value) do
    instances =
      Enum.map(state.instances, fn inst ->
        if inst.url == url, do: %{inst | busy: busy_value}, else: inst
      end)

    %{state | instances: instances}
  end

  # --- Task Ref Tracking ---

  defp track_task_ref(state, ref, url) do
    %{state | task_refs: Map.put(state.task_refs, ref, url)}
  end

  defp remove_task_ref(state, ref) do
    %{state | task_refs: Map.delete(state.task_refs, ref)}
  end

  # --- Instance Config Lookup ---

  defp get_instance_timeout(state, url) do
    case Enum.find(state.instances, fn inst -> inst.url == url end) do
      %{timeout: timeout} -> timeout
      _ -> 120_000
    end
  end

  # --- Warmup ---

  defp warmup_instances(instances) do
    models = warmup_models()
    Enum.each(instances, &warmup_instance(&1, models))
  end

  defp warmup_instance(inst, models) do
    # GPU instances: warm up both vision and text models
    # CPU instances: warm up text model only
    models_to_warm =
      if "gpu" in inst.tags do
        Enum.uniq(Map.values(models))
      else
        List.wrap(models[:text])
      end

    Enum.each(models_to_warm, fn model ->
      Task.Supervisor.start_child(Animina.AI.TaskSupervisor, fn ->
        Client.warmup(inst.url, model)
      end)
    end)
  end

  # Derives warmup model names from the job type registry.
  # Picks the first model found for each family (:vision, :text).
  defp warmup_models do
    AI.job_type_modules()
    |> Enum.reduce(%{}, fn {_type, module}, acc ->
      family = module.model_family()
      Map.put_new(acc, family, module.model())
    end)
  end
end
