defmodule Animina.AI do
  @moduledoc """
  Slim context for the AI job queue.

  Provides enqueue, management, and query functions for AI jobs.
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
    "wingman_suggestion" => Animina.AI.JobTypes.WingmanSuggestion,
    "preheated_wingman" => Animina.AI.JobTypes.PreheatedWingman,
    "spellcheck" => Animina.AI.JobTypes.SpellCheck,
    "greeting_guard" => Animina.AI.JobTypes.GreetingGuard
  }

  @doc "Returns `{:ok, module}` or `:error` for the given job type string."
  def job_type_module(job_type) do
    Map.fetch(@job_type_modules, job_type)
  end

  @doc "Returns the full job type registry map (`%{type_string => module}`)."
  def job_type_modules, do: @job_type_modules

  # --- Enqueue ---

  @doc """
  Enqueues a new AI job and broadcasts to wake the queue.

  ## Options

    * `:priority` - Override default priority (10-50)
    * `:max_attempts` - Override default max attempts
    * `:scheduled_at` - Schedule for later (nil = immediate)
    * `:subject_type` - Polymorphic type ("Photo", "User")
    * `:subject_id` - UUID of the subject entity
    * `:requester_id` - Who triggered it (nil = system)
    * `:model` - Override the default model
    * `:expires_at` - Auto-cancel if not started by this time
  """
  def enqueue(job_type, params, opts \\ []) do
    case job_type_module(job_type) do
      :error ->
        raise ArgumentError, "Unknown job type: #{inspect(job_type)}"

      {:ok, module} ->
        attrs = %{
          job_type: job_type,
          priority: Keyword.get(opts, :priority, module.priority()),
          max_attempts: Keyword.get(opts, :max_attempts, module.max_attempts()),
          scheduled_at: Keyword.get(opts, :scheduled_at),
          params: params,
          subject_type: Keyword.get(opts, :subject_type),
          subject_id: Keyword.get(opts, :subject_id),
          requester_id: Keyword.get(opts, :requester_id),
          model: Keyword.get(opts, :model),
          expires_at: Keyword.get(opts, :expires_at)
        }

        case %Job{} |> Job.create_changeset(attrs) |> Repo.insert() do
          {:ok, _job} = result ->
            Phoenix.PubSub.broadcast(Animina.PubSub, "ai:new_job", :new_job)
            result

          error ->
            error
        end
    end
  end

  @doc """
  Enqueues a job and waits for completion via PubSub.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def enqueue_and_wait(job_type, params, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    case enqueue(job_type, params, opts) do
      {:ok, job} ->
        topic = "ai:result:#{job.id}"
        Phoenix.PubSub.subscribe(Animina.PubSub, topic)

        result =
          receive do
            {:ai_result, ^topic, {:ok, value}} ->
              {:ok, value}

            {:ai_result, ^topic, {:error, reason}} ->
              {:error, reason}
          after
            timeout ->
              {:error, :timeout}
          end

        Phoenix.PubSub.unsubscribe(Animina.PubSub, topic)
        result

      {:error, _} = error ->
        error
    end
  end

  # --- Job Management ---

  @doc "Cancels a pending job. Returns `{:error, :not_cancellable}` for non-pending jobs."
  def cancel(job_id) do
    with {:ok, job} <- fetch_job(job_id) do
      case job do
        %Job{status: "pending"} ->
          job
          |> Job.admin_changeset(%{status: "cancelled"})
          |> Repo.update()

        _ ->
          {:error, :not_cancellable}
      end
    end
  end

  @doc "Cancels a pending or running job with an error reason. Used by the queue on input preparation failures."
  def cancel_with_error(job_id, error) do
    with {:ok, job} <- fetch_job(job_id) do
      case job do
        %Job{status: status} when status in ~w(pending running) ->
          job
          |> Job.admin_changeset(%{status: "cancelled", error: error})
          |> Repo.update()

        _ ->
          {:error, :not_cancellable}
      end
    end
  end

  @doc "Force-cancels a running job (admin action)."
  def force_cancel(job_id) do
    with {:ok, job} <- fetch_job(job_id) do
      case job do
        %Job{status: "running"} ->
          job
          |> Job.admin_changeset(%{status: "cancelled", error: "Force cancelled by admin"})
          |> Repo.update()

        _ ->
          {:error, :not_cancellable}
      end
    end
  end

  @doc "Force-restarts a running job back to pending (admin action)."
  def force_restart(job_id) do
    with {:ok, job} <- fetch_job(job_id) do
      case job do
        %Job{status: "running"} ->
          job
          |> Job.admin_changeset(%{status: "pending", scheduled_at: nil})
          |> Repo.update()

        _ ->
          {:error, :not_restartable}
      end
    end
  end

  @doc "Retries a failed or cancelled job by resetting it to pending."
  def retry(job_id) do
    with {:ok, job} <- fetch_job(job_id) do
      case job do
        %Job{status: status} when status in ~w(failed cancelled) ->
          job
          |> Job.update_changeset(%{status: "pending", scheduled_at: nil})
          |> Repo.update()

        _ ->
          {:error, :not_retryable}
      end
    end
  end

  @doc "Changes the priority of a pending job."
  def reprioritize(job_id, priority) do
    with {:ok, job} <- fetch_job(job_id) do
      case job do
        %Job{status: "pending"} ->
          job
          |> Job.admin_changeset(%{priority: priority})
          |> Repo.update()

        _ ->
          {:error, :not_reprioritizable}
      end
    end
  end

  # --- Queue Control ---

  @doc "Pauses the AI job queue via feature flag."
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

  @doc "Resumes the AI job queue."
  def resume_queue do
    case FeatureFlags.get_flag_setting("system:ai_queue_paused") do
      nil ->
        :ok

      setting ->
        FeatureFlags.update_flag_setting(setting, %{settings: %{value: false}})
    end
  end

  @doc "Returns `true` if the AI job queue is paused."
  def queue_paused? do
    FeatureFlags.get_system_setting_value(:ai_queue_paused, false) == true
  end

  # --- Queries ---

  @doc "Fetches a job by ID, returns `nil` if not found."
  def get_job(id), do: Repo.get(Job, id)

  @doc "Fetches a job by ID, raises if not found."
  def get_job!(id), do: Repo.get!(Job, id)

  @doc "Counts jobs, optionally filtered by `:status`."
  def count_jobs(opts \\ []) do
    query = from(j in Job)

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [j], j.status == ^status)
      end

    Repo.aggregate(query, :count)
  end

  @doc "Lists jobs with filtering, sorting, and pagination options."
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

  @doc "Returns a map of job counts grouped by status."
  def queue_stats do
    stats =
      Job
      |> group_by([j], j.status)
      |> select([j], {j.status, count(j.id)})
      |> Repo.all()
      |> Map.new()

    %{
      pending: Map.get(stats, "pending", 0),
      running: Map.get(stats, "running", 0),
      completed: Map.get(stats, "completed", 0),
      failed: Map.get(stats, "failed", 0),
      cancelled: Map.get(stats, "cancelled", 0)
    }
  end

  @doc "Returns a sorted list of distinct model strings used in jobs."
  def distinct_models do
    Job
    |> where([j], not is_nil(j.model))
    |> distinct([j], j.model)
    |> select([j], j.model)
    |> order_by([j], asc: j.model)
    |> Repo.all()
  end

  @doc "Returns a sorted list of distinct job type strings."
  def distinct_job_types do
    Job
    |> distinct([j], j.job_type)
    |> select([j], j.job_type)
    |> order_by([j], asc: j.job_type)
    |> Repo.all()
  end

  # --- Scheduler Queries ---

  @doc "Returns up to `limit` pending jobs that are ready to run."
  def list_runnable_jobs(limit \\ 10) do
    now = DateTime.utc_now()

    Job
    |> where([j], j.status == "pending")
    |> where([j], is_nil(j.scheduled_at) or j.scheduled_at <= ^now)
    |> where([j], is_nil(j.expires_at) or j.expires_at > ^now)
    |> order_by([j], asc: j.priority, asc: j.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Resets all running jobs to pending (crash recovery on startup)."
  def reset_running_jobs do
    {count, _} =
      Job
      |> where([j], j.status == "running")
      |> Repo.update_all(set: [status: "pending", updated_at: DateTime.utc_now()])

    if count > 0 do
      Logger.info("AI: Reset #{count} running jobs to pending (crash recovery)")
    end

    count
  end

  @stuck_error_prefix "Reset: job stuck running"

  @doc "Resets jobs stuck in running state for longer than `timeout_seconds`."
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
          status: "pending",
          error: "#{@stuck_error_prefix} for over #{timeout_seconds}s",
          updated_at: DateTime.utc_now()
        ]
      )

    if count > 0 do
      Logger.warning("AI: Reset #{count} stuck job(s) running longer than #{timeout_seconds}s")
    end

    count
  end

  @doc "Cancels pending jobs that have passed their `expires_at` time."
  def cancel_expired_jobs do
    now = DateTime.utc_now()

    {count, _} =
      Job
      |> where([j], j.status == "pending")
      |> where([j], not is_nil(j.expires_at) and j.expires_at <= ^now)
      |> Repo.update_all(
        set: [status: "cancelled", error: "Expired", updated_at: DateTime.utc_now()]
      )

    if count > 0, do: Logger.info("AI: Cancelled #{count} expired job(s)")
    count
  end

  @doc "Marks a job as running and increments its attempt counter."
  def mark_running(job) do
    job
    |> Job.update_changeset(%{
      status: "running",
      attempt: (job.attempt || 0) + 1
    })
    |> Repo.update()
  end

  @doc "Marks a running job as completed with result attributes."
  def mark_completed(job, attrs) do
    merged = Map.merge(attrs, %{status: "completed"})
    conditional_update(job, merged)
  end

  @doc "Marks a running job as failed, scheduling a retry if attempts remain."
  def mark_failed(job, error, attrs \\ %{}) do
    merged =
      if job.attempt >= job.max_attempts do
        Map.merge(attrs, %{status: "failed", error: error})
      else
        retry_seconds = 15 * job.attempt
        scheduled_at = DateTime.utc_now() |> DateTime.add(retry_seconds, :second)

        Map.merge(attrs, %{
          status: "pending",
          error: error,
          scheduled_at: scheduled_at
        })
      end

    conditional_update(job, merged)
  end

  defp conditional_update(job, attrs) do
    changeset = Job.update_changeset(job, attrs)

    if changeset.valid? do
      now = DateTime.utc_now()

      set_fields =
        changeset.changes
        |> Map.put(:updated_at, now)
        |> Map.to_list()

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

  @doc "Returns `true` if a pending or running job exists for the given type and subject."
  def has_pending_job?(job_type, subject_type, subject_id) do
    Job
    |> where(
      [j],
      j.job_type == ^job_type and
        j.subject_type == ^subject_type and
        j.subject_id == ^subject_id and
        j.status in ~w(pending running)
    )
    |> Repo.exists?()
  end

  # --- Bulk Operations ---

  @doc "Counts failed jobs inserted since the given datetime."
  def count_failed_since(since) do
    Job
    |> where([j], j.status == "failed")
    |> where([j], j.inserted_at >= ^since)
    |> Repo.aggregate(:count)
  end

  @doc "Resets all failed jobs inserted since `since` back to pending."
  def retry_failed_since(since) do
    Job
    |> where([j], j.status == "failed")
    |> where([j], j.inserted_at >= ^since)
    |> Repo.update_all(
      set: [status: "pending", scheduled_at: nil, updated_at: DateTime.utc_now()]
    )
  end

  # --- Config helpers ---

  @doc """
  Reads AI-related config from the `:animina, Animina.Photos` app env.

  Legacy helper — config lives under `Animina.Photos` for historical reasons.
  Delegates to `Animina.AI.Client.config/2`.
  """
  defdelegate config(key, default), to: Animina.AI.Client

  # --- Private helpers ---

  defp fetch_job(job_id) do
    case Repo.get(Job, job_id) do
      nil -> {:error, :not_found}
      %Job{} = job -> {:ok, job}
    end
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
    do: where(query, [j], j.status in ~w(pending running))

  defp maybe_queue_only(query, _), do: query
end
