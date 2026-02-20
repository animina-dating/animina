defmodule Animina.Analytics.DailyRollup do
  @moduledoc """
  Daily cron job that rolls up analytics data.

  Scheduled to run at 03:00 Berlin time via Quantum.
  Processes yesterday's data:
  1. Rolls up page_views into daily_page_stats
  2. Computes funnel metrics into daily_funnel_stats
  3. Purges raw page_views older than 90 days
  """

  require Logger

  alias Animina.Analytics
  alias Animina.TimeMachine

  def run do
    yesterday = Date.add(TimeMachine.utc_today(), -1)
    Logger.info("[Analytics.DailyRollup] Running rollup for #{yesterday}")

    {:ok, page_count} = Analytics.rollup_page_stats(yesterday)
    Logger.info("[Analytics.DailyRollup] Rolled up #{page_count} page stat rows")

    :ok = Analytics.rollup_funnel_stats(yesterday)
    Logger.info("[Analytics.DailyRollup] Rolled up funnel stats")

    {:ok, purged} = Analytics.purge_old_page_views()
    Logger.info("[Analytics.DailyRollup] Purged #{purged} old page views")
  end
end
