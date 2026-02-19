defmodule Animina.AI do
  @moduledoc """
  Context for the centralized AI job service.

  Provides a unified API for enqueuing, managing, and querying AI jobs
  across all use cases (photo classification, gender guessing, photo descriptions).
  """

  import Ecto.Query

  alias Animina.AI.Job
  alias Animina.FeatureFlags
  alias Animina.Repo
  alias Animina.Repo.Paginator

  require Logger

  # --- Job Type Registry ---

  @job_type_modules %{
    "photo_classification" => Animina.AI.JobTypes.PhotoClassification,
    "gender_guess" => Animina.AI.JobTypes.GenderGuess,
    "photo_description" => Animina.AI.JobTypes.PhotoDescription
  }

  @doc """
  Returns the module implementing a given job type string.
  """
  def job_type_module(job_type) do
    Map.get(@job_type_modules, job_type)
  end

  # --- Enqueue ---

  @doc """
  Enqueues a new AI job.

  ## Options

    * `:priority` - Override default priority (1-5)
    * `:max_attempts` - Override default max attempts
    * `:scheduled_at` - Schedule for later (nil = immediate)
    * `:subject_type` - Polymorphic type ("Photo", "User")
    * `:subject_id` - UUID of the subject entity
    * `:requester_id` - Who triggered it (nil = system)
    * `:model` - Override the default model
  """
  def enqueue(job_type, params, opts \\ []) do
    module = job_type_module(job_type)

    unless module do
      raise ArgumentError, "Unknown job type: #{inspect(job_type)}"
    end

    attrs = %{
      job_type: job_type,
      priority: Keyword.get(opts, :priority, module.default_priority()),
      max_attempts: Keyword.get(opts, :max_attempts, module.max_attempts()),
      scheduled_at: Keyword.get(opts, :scheduled_at),
      params: params,
      subject_type: Keyword.get(opts, :subject_type),
      subject_id: Keyword.get(opts, :subject_id),
      requester_id: Keyword.get(opts, :requester_id),
      model: Keyword.get(opts, :model)
    }

    %Job{}
    |> Job.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Enqueues a job and waits synchronously for its completion.

  Used by GenderGuesser for cache-miss lookups. Creates the job,
  then polls until completed or timeout.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def execute_sync(job_type, params, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    poll_interval = 500

    case enqueue(job_type, params, opts) do
      {:ok, job} ->
        poll_for_completion(job.id, timeout, poll_interval)

      {:error, _} = error ->
        error
    end
  end

  defp poll_for_completion(job_id, timeout, poll_interval) do
    deadline = System.monotonic_time(:millisecond) + timeout

    do_poll(job_id, deadline, poll_interval)
  end

  defp do_poll(job_id, deadline, poll_interval) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      {:error, :timeout}
    else
      case Repo.get(Job, job_id) do
        %Job{status: "completed", result: result} ->
          {:ok, result}

        %Job{status: "failed", error: error} ->
          {:error, {:job_failed, error}}

        %Job{status: "cancelled"} ->
          {:error, :cancelled}

        _ ->
          Process.sleep(min(poll_interval, remaining))
          do_poll(job_id, deadline, poll_interval)
      end
    end
  end

  # --- Job Management ---

  @doc """
  Cancels a job with a terminal error (e.g. deleted photo).
  Bypasses retry logic — sets status to cancelled immediately.
  """
  def cancel_with_error(job_id, error) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      job ->
        job
        |> Job.admin_changeset(%{status: "cancelled", error: error})
        |> Repo.update()
    end
  end

  @doc """
  Cancels a pending or paused job.
  """
  def cancel(job_id) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      %Job{status: status} = job when status in ~w(pending scheduled paused) ->
        job
        |> Job.admin_changeset(%{status: "cancelled"})
        |> Repo.update()

      _ ->
        {:error, :not_cancellable}
    end
  end

  @doc """
  Force-cancels a running job. Sets status to "cancelled" with an admin error message.
  Only works on running jobs.
  """
  def force_cancel(job_id) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      %Job{status: "running"} = job ->
        job
        |> Job.admin_changeset(%{status: "cancelled", error: "Force cancelled by admin"})
        |> Repo.update()

      _ ->
        {:error, :not_cancellable}
    end
  end

  @doc """
  Force-restarts a running job by resetting it to "pending".
  Only works on running jobs.
  """
  def force_restart(job_id) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      %Job{status: "running"} = job ->
        job
        |> Job.admin_changeset(%{status: "pending", scheduled_at: nil})
        |> Repo.update()

      _ ->
        {:error, :not_restartable}
    end
  end

  @doc """
  Retries a failed or cancelled job by resetting it to pending.
  """
  def retry(job_id, opts \\ []) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      %Job{status: status} = job when status in ~w(failed cancelled) ->
        attrs = %{
          status: "pending",
          scheduled_at: nil
        }

        attrs =
          if model = Keyword.get(opts, :model) do
            Map.put(attrs, :model, model)
          else
            attrs
          end

        # Use update_changeset to allow setting model
        job
        |> Job.update_changeset(attrs)
        |> Repo.update()

      _ ->
        {:error, :not_retryable}
    end
  end

  @doc """
  Changes the priority of a pending or scheduled job.
  """
  def reprioritize(job_id, priority) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      %Job{status: status} = job when status in ~w(pending scheduled) ->
        job
        |> Job.admin_changeset(%{priority: priority})
        |> Repo.update()

      _ ->
        {:error, :not_reprioritizable}
    end
  end

  # --- Queue Control ---

  @doc """
  Pauses the entire AI queue. Jobs will not be dispatched until resumed.
  """
  def pause_queue do
    case FeatureFlags.get_or_create_flag_setting("system:ai_queue_paused", %{
           description: "Whether the AI job queue is paused",
           settings: %{value: true}
         }) do
      {:ok, setting} ->
        FeatureFlags.update_flag_setting(setting, %{settings: %{value: true}})

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Resumes the AI queue.
  """
  def resume_queue do
    case FeatureFlags.get_flag_setting("system:ai_queue_paused") do
      nil ->
        :ok

      setting ->
        FeatureFlags.update_flag_setting(setting, %{settings: %{value: false}})
    end
  end

  @doc """
  Returns whether the queue is currently paused.
  """
  def queue_paused? do
    FeatureFlags.get_system_setting_value(:ai_queue_paused, false) == true
  end

  # --- Queries ---

  @doc """
  Gets a single job by ID.
  """
  def get_job(id) do
    Repo.get(Job, id)
  end

  @doc """
  Gets a single job by ID, raising if not found.
  """
  def get_job!(id) do
    Repo.get!(Job, id)
  end

  @doc """
  Lists jobs with pagination, filtering, and sorting.

  ## Options

    * `:page` - page number (default: 1)
    * `:per_page` - items per page (default: 50)
    * `:sort_by` - column to sort by (default: :inserted_at)
    * `:sort_dir` - :asc or :desc (default: :desc)
    * `:filter_job_type` - filter by job type
    * `:filter_status` - filter by status
    * `:filter_priority` - filter by priority
    * `:filter_model` - filter by model
    * `:queue_only` - if true, only show pending/scheduled/running jobs
  """
  def list_jobs(opts \\ []) do
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_dir = Keyword.get(opts, :sort_dir, :desc)

    Job
    |> maybe_filter_job_type(opts[:filter_job_type])
    |> maybe_filter_status(opts[:filter_status])
    |> maybe_filter_priority(opts[:filter_priority])
    |> maybe_filter_model(opts[:filter_model])
    |> maybe_queue_only(opts[:queue_only])
    |> order_by([j], [{^sort_dir, ^sort_by}])
    |> Paginator.paginate(page: opts[:page], per_page: opts[:per_page], max_per_page: 500)
  end

  @doc """
  Counts jobs matching the given filters.
  """
  def count_jobs(opts \\ []) do
    Job
    |> maybe_filter_job_type(opts[:filter_job_type])
    |> maybe_filter_status(opts[:filter_status])
    |> maybe_filter_priority(opts[:filter_priority])
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns queue statistics — counts by status.
  """
  def queue_stats do
    stats =
      Job
      |> group_by([j], j.status)
      |> select([j], {j.status, count(j.id)})
      |> Repo.all()
      |> Map.new()

    %{
      pending: Map.get(stats, "pending", 0) + Map.get(stats, "scheduled", 0),
      running: Map.get(stats, "running", 0),
      completed: Map.get(stats, "completed", 0),
      failed: Map.get(stats, "failed", 0),
      cancelled: Map.get(stats, "cancelled", 0),
      paused: Map.get(stats, "paused", 0)
    }
  end

  @doc """
  Returns a list of distinct model names used in AI jobs.
  """
  def distinct_models do
    Job
    |> where([j], not is_nil(j.model))
    |> distinct([j], j.model)
    |> select([j], j.model)
    |> order_by([j], asc: j.model)
    |> Repo.all()
  end

  @doc """
  Returns a list of distinct job types used in AI jobs.
  """
  def distinct_job_types do
    Job
    |> distinct([j], j.job_type)
    |> select([j], j.job_type)
    |> order_by([j], asc: j.job_type)
    |> Repo.all()
  end

  # --- Bulk Operations ---

  @doc """
  Enqueues photo_description jobs for all approved photos.

  Skips photos that already have a pending/running description job.
  Jobs are enqueued at the given priority (default: 5 = background).

  Returns `{enqueued_count, skipped_count}`.
  """
  def enqueue_all_photo_descriptions(opts \\ []) do
    priority = Keyword.get(opts, :priority, 5)
    requester_id = Keyword.get(opts, :requester_id)

    photo_ids = Animina.Photos.list_approved_photo_ids()

    Enum.reduce(photo_ids, {0, 0}, fn photo_id, {enqueued, skipped} ->
      if has_pending_job?("photo_description", "Photo", photo_id) do
        {enqueued, skipped + 1}
      else
        enqueue("photo_description", %{"photo_id" => photo_id},
          subject_type: "Photo",
          subject_id: photo_id,
          requester_id: requester_id,
          priority: priority
        )

        {enqueued + 1, skipped}
      end
    end)
  end

  @doc """
  Counts failed jobs since the given datetime.
  """
  def count_failed_since(since) do
    Job
    |> where([j], j.status == "failed")
    |> where([j], j.inserted_at >= ^since)
    |> Repo.aggregate(:count)
  end

  @doc """
  Bulk-retries all failed jobs since the given datetime by resetting them to pending.
  Returns `{count, nil}` tuple from `Repo.update_all`.
  """
  def retry_failed_since(since) do
    Job
    |> where([j], j.status == "failed")
    |> where([j], j.inserted_at >= ^since)
    |> Repo.update_all(
      set: [status: "pending", scheduled_at: nil, updated_at: DateTime.utc_now()]
    )
  end

  @doc """
  Reschedules a running job back to scheduled without incrementing the attempt counter.

  Used when a semaphore timeout occurs — the job never actually ran,
  so it shouldn't count against max_attempts.
  """
  def reschedule_running_job(job_id) do
    scheduled_at = DateTime.utc_now() |> DateTime.add(5, :second)

    from(j in Job,
      where: j.id == ^job_id and j.status == "running"
    )
    |> Repo.update_all(
      set: [status: "scheduled", scheduled_at: scheduled_at, updated_at: DateTime.utc_now()]
    )
  end

  # --- Scheduler Queries ---

  @doc """
  Returns runnable jobs: pending or scheduled with scheduled_at <= now.
  Ordered by priority ASC, then inserted_at ASC.
  """
  def list_runnable_jobs(limit \\ 5) do
    now = DateTime.utc_now()

    Job
    |> where([j], j.status in ~w(pending scheduled))
    |> where([j], is_nil(j.scheduled_at) or j.scheduled_at <= ^now)
    |> order_by([j], asc: j.priority, asc: j.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Resets any running jobs back to scheduled (crash recovery on startup).
  """
  def reset_running_jobs do
    {count, _} =
      Job
      |> where([j], j.status == "running")
      |> Repo.update_all(set: [status: "scheduled", updated_at: DateTime.utc_now()])

    if count > 0 do
      Logger.info("AI Scheduler: Reset #{count} running jobs to scheduled (crash recovery)")
    end

    count
  end

  @stuck_error_prefix "Reset: job stuck running"

  @doc """
  Resets jobs that have been running longer than `timeout_seconds` back to "scheduled".

  This catches stuck jobs (e.g., Ollama hangs, Task process crashes without cleanup).
  Each job is only auto-reset once — jobs whose error already starts with the
  stuck prefix are skipped to prevent infinite restart loops.
  Runs as a single efficient SQL query, usually matching 0 rows.
  """
  def reset_stuck_jobs(timeout_seconds \\ 180) do
    cutoff = DateTime.utc_now() |> DateTime.add(-timeout_seconds, :second)
    prefix = @stuck_error_prefix <> "%"

    {count, _} =
      Job
      |> where(
        [j],
        j.status == "running" and j.updated_at < ^cutoff and
          (is_nil(j.error) or not like(j.error, ^prefix))
      )
      |> Repo.update_all(
        set: [
          status: "scheduled",
          error: "#{@stuck_error_prefix} for over #{timeout_seconds}s",
          updated_at: DateTime.utc_now()
        ]
      )

    if count > 0 do
      Logger.warning("AI: Reset #{count} stuck job(s) running longer than #{timeout_seconds}s")
    end

    count
  end

  @doc """
  Marks a job as running with the given attempt number.
  """
  def mark_running(job) do
    job
    |> Job.update_changeset(%{
      status: "running",
      attempt: (job.attempt || 0) + 1
    })
    |> Repo.update()
  end

  @doc """
  Marks a job as completed with its result.

  Uses a conditional UPDATE (WHERE status = 'running') to prevent overwriting
  a job that was cancelled or restarted by an admin while executing.
  Returns `{:error, :job_not_running}` if the job is no longer running.
  """
  def mark_completed(job, attrs) do
    merged = Map.merge(attrs, %{status: "completed"})
    conditional_update(job, merged)
  end

  @doc """
  Marks a job as failed. If max attempts not reached, schedules retry.

  Uses a conditional UPDATE (WHERE status = 'running') to prevent overwriting
  a job that was cancelled or restarted by an admin while executing.
  Returns `{:error, :job_not_running}` if the job is no longer running.
  """
  def mark_failed(job, error, attrs \\ %{}) do
    merged =
      if job.attempt >= job.max_attempts do
        Map.merge(attrs, %{status: "failed", error: error})
      else
        # Schedule retry with backoff: 15 * attempt minutes
        retry_minutes = 15 * job.attempt
        scheduled_at = DateTime.utc_now() |> DateTime.add(retry_minutes, :minute)

        Map.merge(attrs, %{
          status: "scheduled",
          error: error,
          scheduled_at: scheduled_at
        })
      end

    conditional_update(job, merged)
  end

  # Applies an update only if the job is still in "running" status.
  # Returns {:ok, job} or {:error, :job_not_running}.
  defp conditional_update(job, attrs) do
    changeset = Job.update_changeset(job, attrs)

    if changeset.valid? do
      changes = changeset.changes
      now = DateTime.utc_now()

      set_fields =
        changes
        |> Map.put(:updated_at, now)
        |> Enum.map(fn {k, v} -> {k, v} end)

      {count, updated} =
        Job
        |> where([j], j.id == ^job.id and j.status == "running")
        |> select([j], j)
        |> Repo.update_all(set: set_fields)

      case {count, updated} do
        {1, [updated_job]} -> {:ok, updated_job}
        {0, []} -> {:error, :job_not_running}
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Checks if there's already a pending/running job for the given subject.
  """
  def has_pending_job?(job_type, subject_type, subject_id) do
    Job
    |> where(
      [j],
      j.job_type == ^job_type and
        j.subject_type == ^subject_type and
        j.subject_id == ^subject_id and
        j.status in ~w(pending scheduled running)
    )
    |> Repo.exists?()
  end

  # --- Config helpers ---

  @doc """
  Gets an AI config value from application env, with a default.
  """
  def config(key, default) do
    :animina
    |> Application.get_env(Animina.Photos, [])
    |> Keyword.get(key, default)
  end

  # --- Private filter helpers ---

  defp maybe_filter_job_type(query, nil), do: query
  defp maybe_filter_job_type(query, ""), do: query
  defp maybe_filter_job_type(query, type), do: where(query, [j], j.job_type == ^type)

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, ""), do: query
  defp maybe_filter_status(query, status), do: where(query, [j], j.status == ^status)

  defp maybe_filter_priority(query, nil), do: query

  defp maybe_filter_priority(query, priority) when is_integer(priority),
    do: where(query, [j], j.priority == ^priority)

  defp maybe_filter_priority(query, priority) when is_binary(priority) do
    case Integer.parse(priority) do
      {p, ""} -> where(query, [j], j.priority == ^p)
      _ -> query
    end
  end

  defp maybe_filter_model(query, nil), do: query
  defp maybe_filter_model(query, ""), do: query
  defp maybe_filter_model(query, model), do: where(query, [j], j.model == ^model)

  defp maybe_queue_only(query, true),
    do: where(query, [j], j.status in ~w(pending scheduled running))

  defp maybe_queue_only(query, _), do: query
end
