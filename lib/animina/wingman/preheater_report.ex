defmodule Animina.Wingman.PreheaterReport do
  @moduledoc """
  Morning report for the wingman preheater batch.

  Called by Quantum cron at 08:00 Berlin time. Checks how many of
  tonight's preheated hints completed and emails the admin if
  completion is below 100%.
  """

  import Ecto.Query

  alias Animina.Accounts.User
  alias Animina.Accounts.UserNotifier
  alias Animina.AI.Job
  alias Animina.Discovery.Schemas.SpotlightEntry
  alias Animina.FeatureFlags
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Wingman.PreheatedWingmanHint

  require Logger

  @doc """
  Checks preheater completion and emails admin if incomplete.
  """
  def run do
    if FeatureFlags.wingman_enabled?() do
      do_run()
    else
      Logger.info("PreheaterReport: wingman disabled, skipping")
      :disabled
    end
  end

  defp do_run do
    today = berlin_today()
    stats = gather_stats(today)

    Logger.info(
      "PreheaterReport: #{stats.completed_hints}/#{stats.expected_hints} hints " <>
        "(#{stats.completion_pct}%), #{stats.pending_jobs} pending, #{stats.failed_jobs} failed"
    )

    if stats.completion_pct < 100 and stats.expected_hints > 0 do
      UserNotifier.deliver_preheater_report(stats)
      Logger.info("PreheaterReport: sent incomplete report email")
    end

    stats
  end

  @doc """
  Gathers statistics for the preheater batch.
  """
  def gather_stats(today \\ nil) do
    today = today || berlin_today()

    total_users = count_wingman_users()
    expected_hints = count_expected_pairs(today)
    completed_hints = count_completed_hints(today)
    pending_jobs = count_jobs_by_status(~w(pending running))
    failed_jobs = count_jobs_by_status(~w(failed))

    completion_pct =
      if expected_hints > 0,
        do: round(completed_hints / expected_hints * 100),
        else: 100

    %{
      total_users: total_users,
      expected_hints: expected_hints,
      completed_hints: completed_hints,
      pending_jobs: pending_jobs,
      failed_jobs: failed_jobs,
      completion_pct: completion_pct
    }
  end

  defp count_wingman_users do
    User
    |> where([u], u.wingman_enabled == true)
    |> where([u], u.state == "normal")
    |> where([u], not is_nil(u.confirmed_at))
    |> where([u], is_nil(u.deleted_at))
    |> Repo.aggregate(:count)
  end

  defp count_expected_pairs(today) do
    # Count total spotlight entries for wingman users today
    from(e in SpotlightEntry,
      join: u in User,
      on: u.id == e.user_id,
      where: e.shown_on == ^today,
      where: u.wingman_enabled == true,
      where: u.state == "normal",
      where: not is_nil(u.confirmed_at),
      where: is_nil(u.deleted_at)
    )
    |> Repo.aggregate(:count)
  end

  defp count_completed_hints(today) do
    from(h in PreheatedWingmanHint,
      where: h.shown_on == ^today and not is_nil(h.suggestions)
    )
    |> Repo.aggregate(:count)
  end

  defp count_jobs_by_status(statuses) do
    Job
    |> where([j], j.job_type == "preheated_wingman")
    |> where([j], j.status in ^statuses)
    |> Repo.aggregate(:count)
  end

  defp berlin_today do
    TimeMachine.utc_now()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> DateTime.to_date()
  end
end
