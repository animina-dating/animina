defmodule Animina.Accounts.OnlineActivity do
  @moduledoc """
  Query module for user online activity analysis.

  Provides functions for:
  - Last seen status
  - Activity frequency (daily, weekly, etc.)
  - Typical online times (morning, afternoon, evening, night)
  - Session purging
  """

  import Ecto.Query
  use Gettext, backend: AniminaWeb.Gettext

  alias Animina.Accounts.UserOnlineSession
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Utils.Timezone

  @doc """
  Returns the user's online status.

  - `:online` if an open session exists
  - `%DateTime{}` of the latest `ended_at` if offline
  - `nil` if no session data exists
  """
  def last_seen(user_id) do
    # Check for open session first
    open_query =
      from(s in UserOnlineSession,
        where: s.user_id == ^user_id,
        where: is_nil(s.ended_at),
        select: 1,
        limit: 1
      )

    if Repo.exists?(open_query) do
      :online
    else
      from(s in UserOnlineSession,
        where: s.user_id == ^user_id,
        where: not is_nil(s.ended_at),
        order_by: [desc: s.ended_at],
        select: s.ended_at,
        limit: 1
      )
      |> Repo.one()
    end
  end

  @doc """
  Returns an atom describing how frequently the user is online.

  Counts distinct days with sessions in the last `days` days and maps
  the ratio to: `:daily`, `:most_days`, `:several_times_a_week`,
  `:weekly`, `:rarely`, or `:inactive`.
  """
  def activity_level(user_id, days \\ 30) do
    cutoff =
      TimeMachine.utc_now()
      |> DateTime.add(-days, :day)
      |> DateTime.truncate(:second)

    distinct_days =
      from(s in UserOnlineSession,
        where: s.user_id == ^user_id,
        where: s.started_at >= ^cutoff,
        select: fragment("COUNT(DISTINCT DATE(?))", s.started_at)
      )
      |> Repo.one()

    ratio = distinct_days / days

    cond do
      distinct_days == 0 -> :inactive
      ratio >= 0.85 -> :daily
      ratio >= 0.60 -> :most_days
      ratio >= 0.35 -> :several_times_a_week
      ratio >= 0.15 -> :weekly
      true -> :rarely
    end
  end

  @doc """
  Returns a list of time block atoms where the user is typically online.

  Analyzes session hours over the last `days` days, buckets them into
  morning (6-12), afternoon (12-18), evening (18-24), night (0-6).
  Returns blocks accounting for >= 25% of total minutes, sorted by prevalence.

  Returns `[]` if less than 30 minutes of total data.
  """
  def typical_online_times(user_id, days \\ 30) do
    cutoff =
      TimeMachine.utc_now()
      |> DateTime.add(-days, :day)
      |> DateTime.truncate(:second)

    offset_seconds = Timezone.berlin_utc_offset_seconds()

    # Get all closed sessions in the period
    sessions =
      from(s in UserOnlineSession,
        where: s.user_id == ^user_id,
        where: s.started_at >= ^cutoff,
        where: not is_nil(s.ended_at),
        where: s.duration_minutes > 0,
        select: {s.started_at, s.ended_at}
      )
      |> Repo.all()

    # Compute minutes per time block
    block_minutes = compute_block_minutes(sessions, offset_seconds)
    total = Enum.sum(Map.values(block_minutes))

    if total < 30 do
      []
    else
      block_minutes
      |> Enum.filter(fn {_block, mins} -> mins / total >= 0.25 end)
      |> Enum.sort_by(fn {_block, mins} -> -mins end)
      |> Enum.map(fn {block, _mins} -> block end)
    end
  end

  @doc """
  Deletes closed sessions older than `days` days.
  """
  def purge_old_sessions(days \\ 90) do
    cutoff =
      TimeMachine.utc_now()
      |> DateTime.add(-days, :day)
      |> DateTime.truncate(:second)

    from(s in UserOnlineSession,
      where: not is_nil(s.ended_at),
      where: s.started_at < ^cutoff
    )
    |> Repo.delete_all()
  end

  @doc """
  Returns a translated label for an activity level atom.
  """
  def activity_level_label(:daily), do: gettext("Online daily")
  def activity_level_label(:most_days), do: gettext("Online most days")

  def activity_level_label(:several_times_a_week),
    do: gettext("Online several times a week")

  def activity_level_label(:weekly), do: gettext("Online weekly")
  def activity_level_label(:rarely), do: gettext("Rarely online")
  def activity_level_label(:inactive), do: nil

  @doc """
  Returns a translated label for a list of typical time blocks.
  """
  def typical_times_label([]), do: nil

  def typical_times_label(blocks) when is_list(blocks) do
    time_names = Enum.map_join(blocks, ", ", &time_block_name/1)
    gettext("Usually online in the %{time}", time: time_names)
  end

  defp time_block_name(:morning), do: gettext("morning")
  defp time_block_name(:afternoon), do: gettext("afternoon")
  defp time_block_name(:evening), do: gettext("evening")
  defp time_block_name(:night), do: gettext("night")

  # Compute minutes spent in each time block across all sessions
  defp compute_block_minutes(sessions, offset_seconds) do
    initial = %{morning: 0, afternoon: 0, evening: 0, night: 0}

    Enum.reduce(sessions, initial, fn {started_at, ended_at}, acc ->
      distribute_session_to_blocks(started_at, ended_at, offset_seconds, acc)
    end)
  end

  # Distribute a single session's minutes across time blocks
  defp distribute_session_to_blocks(started_at, ended_at, offset_seconds, acc) do
    # Convert to Berlin local hours
    start_seconds = DateTime.to_unix(started_at) + offset_seconds
    end_seconds = DateTime.to_unix(ended_at) + offset_seconds

    # Walk through minute-by-minute would be slow; instead walk hour boundaries
    distribute_by_hours(start_seconds, end_seconds, acc)
  end

  defp distribute_by_hours(start_seconds, end_seconds, acc) when start_seconds >= end_seconds do
    acc
  end

  defp distribute_by_hours(start_seconds, end_seconds, acc) do
    hour = rem(div(start_seconds, 3600), 24)
    hour = if hour < 0, do: hour + 24, else: hour
    block = hour_to_block(hour)

    # Minutes until next hour boundary or end of session
    seconds_in_current_hour = rem(start_seconds, 3600)
    seconds_until_next_hour = 3600 - seconds_in_current_hour
    chunk_seconds = min(seconds_until_next_hour, end_seconds - start_seconds)
    chunk_minutes = chunk_seconds / 60

    acc = Map.update!(acc, block, &(&1 + chunk_minutes))
    distribute_by_hours(start_seconds + chunk_seconds, end_seconds, acc)
  end

  defp hour_to_block(hour) when hour >= 6 and hour < 12, do: :morning
  defp hour_to_block(hour) when hour >= 12 and hour < 18, do: :afternoon
  defp hour_to_block(hour) when hour >= 18 and hour < 24, do: :evening
  defp hour_to_block(_hour), do: :night
end
