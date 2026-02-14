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
  alias Animina.AI.Semaphore
  alias Animina.FeatureFlags
  alias Animina.Photos

  @default_poll_interval_ms 5_000
  @default_batch_size 5
  @description_seed_interval_ms 60_000
  @stuck_job_timeout_seconds 180

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

    batch_size =
      Keyword.get(opts, :batch_size, read_setting(:ai_scheduler_batch_size, @default_batch_size))

    state = %{
      poll_interval: poll_interval,
      batch_size: batch_size,
      total_dispatched: 0,
      last_description_seed_at: 0
    }

    # Crash recovery: reset any running jobs
    AI.reset_running_jobs()

    # Schedule first poll after startup delay
    Process.send_after(self(), :poll, 3_000)

    Logger.info(
      "AI.Scheduler started with poll_interval=#{poll_interval}ms, batch_size=#{batch_size}"
    )

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = do_poll(state)
    Process.send_after(self(), :poll, state.poll_interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:poll, state) do
    state = do_poll(state)
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

  defp do_poll(state) do
    AI.reset_stuck_jobs(@stuck_job_timeout_seconds)

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
      batch = min(state.batch_size, available)
      jobs = AI.list_runnable_jobs(batch)
      Enum.each(jobs, &dispatch_job/1)
      dispatched = length(jobs)

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

  defp dispatch_job(job) do
    Task.Supervisor.start_child(Animina.AI.TaskSupervisor, fn ->
      Executor.run(job)
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
