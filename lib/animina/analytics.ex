defmodule Animina.Analytics do
  @moduledoc """
  Context for self-hosted analytics.

  Provides page view recording, real-time and historical queries,
  funnel metrics, retention analysis, and daily rollup functions.
  """

  import Ecto.Query

  alias Animina.Accounts.ProfileCompleteness
  alias Animina.Accounts.UserOnlineSession
  alias Animina.ActivityLog
  alias Animina.ActivityLog.ActivityLogEntry
  alias Animina.Analytics.DailyFunnelStat
  alias Animina.Analytics.DailyPageStat
  alias Animina.Analytics.PageView
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Utils.Timezone

  # -------------------------------------------------------------------
  # Recording
  # -------------------------------------------------------------------

  @doc """
  Inserts a page view record.
  """
  def record_page_view(attrs) do
    %PageView{}
    |> PageView.changeset(attrs)
    |> Repo.insert()
  end

  # -------------------------------------------------------------------
  # Real-time queries (from raw page_views, today only)
  # -------------------------------------------------------------------

  @doc """
  All today's stats in a single call: page views, unique sessions, unique users.
  Computes the Berlin time range once and runs a single query.
  """
  def today_stats do
    {start_utc, end_utc} = Timezone.berlin_today_utc_range()

    from(pv in PageView,
      where: pv.inserted_at >= ^start_utc and pv.inserted_at < ^end_utc,
      select: %{
        page_views: count(),
        unique_sessions: count(pv.session_id, :distinct),
        unique_users: fragment("count(distinct ?) filter (where ? is not null)", pv.user_id, pv.user_id)
      }
    )
    |> Repo.one()
  end

  @doc """
  Total page view count for today (Berlin time).
  """
  def page_view_count_today do
    today_stats().page_views
  end

  @doc """
  Top pages today ranked by view count.
  """
  def top_pages_today(limit \\ 10) do
    {start_utc, end_utc} = Timezone.berlin_today_utc_range()

    from(pv in PageView,
      where: pv.inserted_at >= ^start_utc and pv.inserted_at < ^end_utc,
      group_by: pv.path,
      select: %{path: pv.path, views: count()},
      order_by: [desc: count()],
      limit: ^limit
    )
    |> Repo.all()
  end

  # -------------------------------------------------------------------
  # Historical queries (from rollup tables)
  # -------------------------------------------------------------------

  @doc """
  Daily totals from `daily_page_stats` for the last `days` days.
  Returns a list of `%{date, view_count, unique_sessions, unique_users}`.
  """
  def daily_totals(days \\ 30) do
    cutoff = Date.add(TimeMachine.utc_today(), -days)

    from(s in DailyPageStat,
      where: s.date >= ^cutoff,
      group_by: s.date,
      select: %{
        date: s.date,
        view_count: sum(s.view_count),
        unique_sessions: sum(s.unique_sessions),
        unique_users: sum(s.unique_users)
      },
      order_by: [asc: s.date]
    )
    |> Repo.all()
  end

  @doc """
  Top pages over a period ranked by total views.
  """
  def top_pages(days \\ 30, limit \\ 20) do
    cutoff = Date.add(TimeMachine.utc_today(), -days)

    from(s in DailyPageStat,
      where: s.date >= ^cutoff,
      group_by: s.path,
      select: %{
        path: s.path,
        view_count: sum(s.view_count),
        unique_sessions: sum(s.unique_sessions),
        unique_users: sum(s.unique_users)
      },
      order_by: [desc: sum(s.view_count)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Daily funnel rows for the last `days` days.
  """
  def funnel_stats(days \\ 30) do
    cutoff = Date.add(TimeMachine.utc_today(), -days)

    from(f in DailyFunnelStat,
      where: f.date >= ^cutoff,
      order_by: [asc: f.date]
    )
    |> Repo.all()
  end

  @doc """
  Aggregated funnel sums over the last `days` days.
  """
  def funnel_totals(days \\ 30) do
    cutoff = Date.add(TimeMachine.utc_today(), -days)

    from(f in DailyFunnelStat,
      where: f.date >= ^cutoff,
      select: %{
        visitors: coalesce(sum(f.visitors), 0),
        registered: coalesce(sum(f.registered), 0),
        profile_completed: coalesce(sum(f.profile_completed), 0),
        first_message: coalesce(sum(f.first_message), 0),
        mutual_match: coalesce(sum(f.mutual_match), 0)
      }
    )
    |> Repo.one()
  end

  # -------------------------------------------------------------------
  # Retention (from user_online_sessions)
  # -------------------------------------------------------------------

  @doc """
  Returns `%{dau: N, wau: N, mau: N}` based on distinct user_ids
  in `user_online_sessions`.
  """
  def active_user_counts do
    now = TimeMachine.utc_now()
    day_ago = DateTime.add(now, -1, :day)
    week_ago = DateTime.add(now, -7, :day)
    month_ago = DateTime.add(now, -30, :day)

    %{
      dau: count_active_since(day_ago),
      wau: count_active_since(week_ago),
      mau: count_active_since(month_ago)
    }
  end

  defp count_active_since(since) do
    from(s in UserOnlineSession,
      where: s.started_at >= ^since or (is_nil(s.ended_at) and s.started_at < ^since),
      select: count(s.user_id, :distinct)
    )
    |> Repo.one()
  end

  @doc """
  Daily distinct active users for the last `days` days (for trend chart).
  """
  def dau_series(days \\ 30) do
    cutoff = DateTime.add(TimeMachine.utc_now(), -days, :day)

    from(s in UserOnlineSession,
      where: s.started_at >= ^cutoff,
      group_by: fragment("?::date", s.started_at),
      select: %{
        date: fragment("?::date", s.started_at),
        count: count(s.user_id, :distinct)
      },
      order_by: [asc: fragment("?::date", s.started_at)]
    )
    |> Repo.all()
  end

  @doc """
  DAU/MAU ratio (stickiness). Returns a float between 0.0 and 1.0.

  Accepts optional pre-computed `active_user_counts()` map to avoid
  redundant DB queries when the caller already has the data.
  """
  def dau_mau_ratio(counts \\ nil) do
    %{dau: dau, mau: mau} = counts || active_user_counts()
    if mau > 0, do: Float.round(dau / mau, 3), else: 0.0
  end

  # -------------------------------------------------------------------
  # Feature engagement (from activity_logs)
  # -------------------------------------------------------------------

  @tracked_events ~w(message_sent profile_visit bookmark_added moodboard_changed flags_changed dismissal_created conversation_created)

  @doc """
  Counts of key engagement events over the last `days` days.
  Returns a list of `%{event: String.t(), count: integer()}`.
  """
  def feature_engagement(days \\ 30) do
    cutoff = DateTime.add(TimeMachine.utc_now(), -days, :day)

    from(e in ActivityLogEntry,
      where: e.event in ^@tracked_events,
      where: e.inserted_at >= ^cutoff,
      group_by: e.event,
      select: %{event: e.event, count: count()},
      order_by: [desc: count()]
    )
    |> Repo.all()
  end

  # -------------------------------------------------------------------
  # Rollup functions (called by daily cron)
  # -------------------------------------------------------------------

  @doc """
  Aggregate page_views into daily_page_stats for a given date.
  Idempotent: deletes existing rows for the date, then re-inserts.
  """
  def rollup_page_stats(date) do
    {start_utc, end_utc} = Timezone.berlin_date_utc_range(date)

    # Delete existing rollups for this date
    from(s in DailyPageStat, where: s.date == ^date)
    |> Repo.delete_all()

    # Compute and insert new rollups
    rows =
      from(pv in PageView,
        where: pv.inserted_at >= ^start_utc and pv.inserted_at < ^end_utc,
        group_by: pv.path,
        select: %{
          path: pv.path,
          view_count: count(),
          unique_sessions: count(pv.session_id, :distinct),
          unique_users: count(pv.user_id, :distinct)
        }
      )
      |> Repo.all()

    Enum.each(rows, fn row ->
      %DailyPageStat{}
      |> DailyPageStat.changeset(Map.put(row, :date, date))
      |> Repo.insert!()
    end)

    {:ok, length(rows)}
  end

  @doc """
  Compute funnel metrics for a given date from page_views + activity_logs.
  Idempotent: deletes existing row for the date, then re-inserts.
  """
  def rollup_funnel_stats(date) do
    {start_utc, end_utc} = Timezone.berlin_date_utc_range(date)

    # Delete existing
    from(f in DailyFunnelStat, where: f.date == ^date)
    |> Repo.delete_all()

    visitors =
      from(pv in PageView,
        where: pv.inserted_at >= ^start_utc and pv.inserted_at < ^end_utc,
        select: count(pv.session_id, :distinct)
      )
      |> Repo.one()

    registered = count_events_in_range("account_registered", start_utc, end_utc)
    profile_completed = count_events_in_range("profile_completed", start_utc, end_utc)
    mutual_match = count_events_in_range("relationship_accepted", start_utc, end_utc)

    # First message: users whose first-ever message_sent event falls on this date.
    # Uses a subquery to find each user's first message_sent, then counts those in range.
    first_messages_subquery =
      from(e in ActivityLogEntry,
        where: e.event == "message_sent",
        where: not is_nil(e.actor_id),
        group_by: e.actor_id,
        select: %{actor_id: e.actor_id, first_at: min(e.inserted_at)}
      )

    first_message =
      from(f in subquery(first_messages_subquery),
        where: f.first_at >= ^start_utc and f.first_at < ^end_utc,
        select: count()
      )
      |> Repo.one() || 0

    %DailyFunnelStat{}
    |> DailyFunnelStat.changeset(%{
      date: date,
      visitors: visitors,
      registered: registered,
      profile_completed: profile_completed,
      first_message: first_message,
      mutual_match: mutual_match
    })
    |> Repo.insert!()

    :ok
  end

  defp count_events_in_range(event, start_utc, end_utc) do
    from(e in ActivityLogEntry,
      where: e.event == ^event,
      where: e.inserted_at >= ^start_utc and e.inserted_at < ^end_utc,
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Delete raw page_views older than `days` days.
  """
  def purge_old_page_views(days \\ 90) do
    cutoff = DateTime.add(TimeMachine.utc_now(), -days, :day)

    {count, _} =
      from(pv in PageView, where: pv.inserted_at < ^cutoff)
      |> Repo.delete_all()

    {:ok, count}
  end

  # -------------------------------------------------------------------
  # Profile completed helper
  # -------------------------------------------------------------------

  @doc """
  Logs a `profile_completed` activity event if the user's profile is
  fully complete and no such event has been logged before.
  """
  def maybe_log_profile_completed(user) do
    completeness = ProfileCompleteness.compute(user)

    if completeness.completed_count == completeness.total_count do
      already =
        Repo.exists?(
          from(e in ActivityLogEntry,
            where: e.actor_id == ^user.id and e.event == "profile_completed"
          )
        )

      unless already do
        ActivityLog.log("profile", "profile_completed",
          "User #{user.display_name} completed their profile",
          actor_id: user.id
        )
      end
    end
  end

end
