defmodule Animina.ActivityLog do
  @moduledoc """
  Context for the unified activity logging system.

  Provides a single API for recording all important events across the application.
  Events are stored in the `activity_logs` table and viewable at `/admin/logs/activity`.
  """

  import Ecto.Query

  alias Animina.ActivityLog.ActivityLogEntry
  alias Animina.Repo

  @pubsub_topic "activity_logs"

  @doc """
  Creates an activity log entry and broadcasts it via PubSub.

  ## Options

    * `:actor_id` - UUID of the user who performed the action
    * `:subject_id` - UUID of the user who was affected
    * `:metadata` - map of event-specific data

  ## Examples

      ActivityLog.log("auth", "login_email", "User Max logged in via email",
        actor_id: user.id
      )

      ActivityLog.log("admin", "role_granted", "Admin gave moderator role to Lisa",
        actor_id: admin.id,
        subject_id: lisa.id,
        metadata: %{role: "moderator"}
      )
  """
  def log(category, event, summary, opts \\ []) do
    attrs = %{
      category: category,
      event: event,
      summary: summary,
      actor_id: Keyword.get(opts, :actor_id),
      subject_id: Keyword.get(opts, :subject_id),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    case %ActivityLogEntry{}
         |> ActivityLogEntry.changeset(attrs)
         |> Repo.insert() do
      {:ok, entry} ->
        entry = Repo.preload(entry, [:actor, :subject])
        broadcast(entry)
        {:ok, entry}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists activity logs with filtering, sorting, and pagination.

  ## Options

    * `:page` - page number (default: 1)
    * `:per_page` - results per page (default: 50)
    * `:sort_dir` - :asc or :desc (default: :desc)
    * `:filter_category` - filter by category
    * `:filter_event` - filter by event
    * `:filter_user_id` - filter by actor_id OR subject_id
    * `:date_from` - filter entries after this date
    * `:date_to` - filter entries before this date
  """
  def list_activity_logs(opts \\ []) do
    page = Keyword.get(opts, :page, 1) |> max(1)
    per_page = Keyword.get(opts, :per_page, 50) |> max(1) |> min(500)
    sort_dir = Keyword.get(opts, :sort_dir, :desc)

    query =
      from(e in ActivityLogEntry,
        left_join: a in assoc(e, :actor),
        left_join: s in assoc(e, :subject),
        preload: [actor: a, subject: s]
      )
      |> maybe_filter_category(Keyword.get(opts, :filter_category))
      |> maybe_filter_event(Keyword.get(opts, :filter_event))
      |> maybe_filter_user(Keyword.get(opts, :filter_user_id))
      |> maybe_filter_date_from(Keyword.get(opts, :date_from))
      |> maybe_filter_date_to(Keyword.get(opts, :date_to))
      |> order_by([e], [{^sort_dir, e.inserted_at}])

    total_count = Repo.aggregate(query, :count)
    total_pages = max(ceil(total_count / per_page), 1)

    entries =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Returns the total count of activity log entries.
  """
  def count do
    Repo.aggregate(ActivityLogEntry, :count)
  end

  @doc """
  Returns the PubSub topic for activity log broadcasts.
  """
  def pubsub_topic, do: @pubsub_topic

  # --- PubSub ---

  defp broadcast(entry) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      @pubsub_topic,
      {:new_activity_log, entry}
    )
  end

  # --- Filters ---

  defp maybe_filter_category(query, nil), do: query
  defp maybe_filter_category(query, ""), do: query
  defp maybe_filter_category(query, cat), do: where(query, [e], e.category == ^cat)

  defp maybe_filter_event(query, nil), do: query
  defp maybe_filter_event(query, ""), do: query
  defp maybe_filter_event(query, event), do: where(query, [e], e.event == ^event)

  defp maybe_filter_user(query, nil), do: query
  defp maybe_filter_user(query, ""), do: query

  defp maybe_filter_user(query, user_id) do
    where(query, [e], e.actor_id == ^user_id or e.subject_id == ^user_id)
  end

  defp maybe_filter_date_from(query, nil), do: query
  defp maybe_filter_date_from(query, ""), do: query

  defp maybe_filter_date_from(query, date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        where(query, [e], e.inserted_at >= ^dt)

      _ ->
        query
    end
  end

  defp maybe_filter_date_to(query, nil), do: query
  defp maybe_filter_date_to(query, ""), do: query

  defp maybe_filter_date_to(query, date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        dt = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
        where(query, [e], e.inserted_at <= ^dt)

      _ ->
        query
    end
  end
end
