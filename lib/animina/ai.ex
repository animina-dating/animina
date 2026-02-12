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
    |> Repo.update_all(set: [status: "pending", scheduled_at: nil, updated_at: DateTime.utc_now()])
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
  """
  def mark_completed(job, attrs) do
    job
    |> Job.update_changeset(Map.merge(attrs, %{status: "completed"}))
    |> Repo.update()
  end

  @doc """
  Marks a job as failed. If max attempts not reached, schedules retry.
  """
  def mark_failed(job, error, attrs \\ %{}) do
    if job.attempt >= job.max_attempts do
      job
      |> Job.update_changeset(Map.merge(attrs, %{status: "failed", error: error}))
      |> Repo.update()
    else
      # Schedule retry with backoff: 15 * attempt minutes
      retry_minutes = 15 * job.attempt
      scheduled_at = DateTime.utc_now() |> DateTime.add(retry_minutes, :minute)

      job
      |> Job.update_changeset(
        Map.merge(attrs, %{
          status: "scheduled",
          error: error,
          scheduled_at: scheduled_at
        })
      )
      |> Repo.update()
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
