defmodule Animina.Discovery.PopularityAggregator do
  @moduledoc """
  Background job for aggregating daily popularity statistics.

  Runs nightly to:
  1. Aggregate yesterday's inquiry counts
  2. Compute rolling 7-day and 30-day averages
  3. Clean up old statistics (older than 60 days)

  Scheduled via Quantum in config.exs to run at 2 AM UTC.
  """

  require Logger

  alias Animina.Discovery.{Popularity, Settings}

  @doc """
  Entry point for the scheduled job.

  Called by Quantum at 2 AM UTC daily.
  """
  def run do
    if Settings.popularity_enabled?() do
      Logger.info("[PopularityAggregator] Starting daily aggregation")
      do_aggregate()
    else
      Logger.debug("[PopularityAggregator] Skipped - popularity protection disabled")
      :ok
    end
  end

  defp do_aggregate do
    # Aggregate yesterday's data (since we run after midnight)
    yesterday = Date.add(Date.utc_today(), -1)

    {:ok, count} = Popularity.aggregate_daily_counts(yesterday)
    Logger.info("[PopularityAggregator] Aggregated stats for #{count} users")

    # Clean up old stats
    {:ok, deleted} = Popularity.cleanup_old_stats(60)

    if deleted > 0 do
      Logger.info("[PopularityAggregator] Cleaned up #{deleted} old stats")
    end

    :ok
  end
end
