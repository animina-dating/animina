defmodule Animina.AI.Scheduler do
  @moduledoc """
  GenServer that polls the database for runnable AI jobs and dispatches
  them to the Executor via Task.Supervisor.

  Responsibilities:
  - Poll every N seconds for runnable jobs (pending/scheduled with scheduled_at <= now)
  - Respect semaphore capacity
  - Reset running jobs on startup (crash recovery)
  - Respect the global pause flag
  - Periodically seed photo description jobs
  """

  use GenServer
  require Logger

  alias Animina.AI
  alias Animina.AI.Executor
  alias Animina.AI.HealthAlert
  alias Animina.AI.PerformanceStats
  alias Animina.AI.Semaphore
  alias Animina.FeatureFlags
  alias Animina.Photos

  @default_poll_interval_ms 5_000
  @description_seed_interval_ms 60_000
  @stuck_job_timeout_seconds 180

  # Per GPU, at most this many jobs may be deferred (skip_for_gpu) per poll cycle.
  # E.g. with 1 GPU and multiplier 2: max 2 jobs wait for GPU, rest forced to CPU.
  @gpu_queue_multiplier 2

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Triggers an immediate poll (for testing).
  """
  def trigger_poll(server \\ __MODULE__) do
    GenServer.cast(server, :poll)
  end

  @doc """
  Returns scheduler statistics.
  """
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    poll_interval =
      Keyword.get(
        opts,
        :poll_interval_ms,
        read_setting(:ai_scheduler_poll_interval, @default_poll_interval_ms)
      )

    state = %{
      poll_interval: poll_interval,
      total_dispatched: 0,
      last_description_seed_at: 0,
      all_down_since: nil,
      last_health_alert_at: nil
    }

    # Crash recovery: reset any running jobs
    AI.reset_running_jobs()

    # Wake up immediately when a semaphore slot frees with no waiter
    Phoenix.PubSub.subscribe(Animina.PubSub, "ai:slot_available")

    # Schedule first poll after startup delay
    Process.send_after(self(), :poll, 3_000)

    Logger.info("AI.Scheduler started with poll_interval=#{poll_interval}ms")

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = do_poll(state, maintenance: true)
    Process.send_after(self(), :poll, state.poll_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:slot_available, state) do
    {:noreply, do_poll(state, maintenance: false)}
  end

  @impl true
  def handle_cast(:poll, state) do
    state = do_poll(state, maintenance: true)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = AI.queue_stats()

    {:reply,
     Map.merge(stats, %{
       total_dispatched: state.total_dispatched,
       paused: AI.queue_paused?()
     }), state}
  end

  # --- Private ---

  defp do_poll(state, opts) do
    state =
      if Keyword.get(opts, :maintenance, true) do
        AI.cancel_expired_jobs()
        AI.reset_stuck_jobs(@stuck_job_timeout_seconds)
        HealthAlert.check(state)
      else
        state
      end

    if AI.queue_paused?() do
      state
    else
      state
      |> maybe_seed_descriptions()
      |> dispatch_jobs()
    end
  end

  defp dispatch_jobs(state) do
    # Check available semaphore slots
    semaphore_status = Semaphore.status()
    available = semaphore_status.max - semaphore_status.active - semaphore_status.waiting

    if available <= 0 do
      state
    else
      slots_to_fill = available
      max_gpu_queue = Executor.get_gpu_instance_count() * @gpu_queue_multiplier
      # Fetch extra jobs so we can skip GPU-waiting ones and still fill CPU slots
      jobs = AI.list_runnable_jobs(max(slots_to_fill * 5, 20))
      initial_depth = PerformanceStats.count_deferred_jobs()

      {dispatched, _depth, _gpu_queued} =
        Enum.reduce_while(jobs, {0, initial_depth, 0}, fn job, {count, depth, gpu_queued} ->
          if count >= slots_to_fill do
            {:halt, {count, depth, gpu_queued}}
          else
            case route_with_gpu_cap(job, depth, gpu_queued, max_gpu_queue) do
              {:dispatch, route, new_depth} ->
                dispatch_job(job, route)
                new_gpu_queued = if gpu_route?(route), do: gpu_queued + 1, else: gpu_queued
                {:cont, {count + 1, new_depth, new_gpu_queued}}

              {:skip_for_gpu, new_depth} ->
                # Job stays in queue, picked up when GPU frees
                {:cont, {count, new_depth, gpu_queued + 1}}
            end
          end
        end)

      if dispatched > 0 do
        Logger.debug("AI.Scheduler: Dispatched #{dispatched} job(s)")
      end

      %{state | total_dispatched: state.total_dispatched + dispatched}
    end
  end

  defp maybe_seed_descriptions(state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.last_description_seed_at

    if elapsed >= @description_seed_interval_ms do
      seed_photo_descriptions()
      %{state | last_description_seed_at: now}
    else
      state
    end
  end

  defp seed_photo_descriptions do
    Photos.list_photos_needing_description(3)
    |> Enum.reject(&AI.has_pending_job?("photo_description", "Photo", &1.id))
    |> Enum.each(&enqueue_description_job/1)
  rescue
    e ->
      Logger.warning("AI.Scheduler: Failed to seed photo descriptions: #{inspect(e)}")
  end

  defp route_with_gpu_cap(job, gpu_depth, gpu_queued, max_gpu_queue) do
    case AI.job_type_module(job.job_type) do
      {:ok, module} ->
        case Executor.pre_route(job, module, gpu_depth) do
          {:skip_for_gpu, new_depth} when gpu_queued >= max_gpu_queue ->
            # GPU queue is full — force this job to CPU instead of waiting
            model = module.default_model()
            model_family = module.model_family()
            Executor.force_cpu(job, model_family, model, new_depth)

          other ->
            other
        end

      :error ->
        {:dispatch, nil, gpu_depth}
    end
  end

  defp gpu_route?({:run_gpu, _model}), do: true
  defp gpu_route?(_), do: false

  defp dispatch_job(job, route) do
    Task.Supervisor.start_child(Animina.AI.TaskSupervisor, fn ->
      Executor.run(job, route)
    end)
  end

  defp enqueue_description_job(photo) do
    owner_id = if photo.owner_type == "User", do: photo.owner_id, else: nil

    AI.enqueue("photo_description", %{"photo_id" => photo.id},
      subject_type: "Photo",
      subject_id: photo.id,
      requester_id: owner_id
    )
  end

  defp read_setting(name, default) do
    FeatureFlags.get_system_setting_value(name, default)
  rescue
    _ -> default
  end
end
