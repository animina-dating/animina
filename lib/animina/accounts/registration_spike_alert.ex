defmodule Animina.Accounts.RegistrationSpikeAlert do
  @moduledoc """
  Quantum job that checks for registration spikes every 2 hours (06:00-20:00 Berlin).

  Compares today's confirmed registrations against the 30-day rolling daily average.
  When registrations exceed 1.5x the average, sends a statistical overview email.
  """

  require Logger

  alias Animina.Accounts
  alias Animina.Accounts.UserNotifier

  @recipient {"Stefan Wintermeyer", "sw@wintermeyer-consulting.de"}
  @spike_multiplier 1.5

  def run do
    today_count = Accounts.count_confirmed_users_today_berlin()
    daily_average = Accounts.average_daily_confirmed_users_last_30_days()
    threshold = daily_average * @spike_multiplier

    if today_count > 0 and today_count >= threshold do
      yesterday_count = Accounts.count_confirmed_users_yesterday_berlin()
      hourly_breakdown = Accounts.confirmed_users_today_by_hour_berlin()

      spike_factor =
        if daily_average > 0, do: today_count / daily_average, else: today_count / 1.0

      stats = %{
        today_count: today_count,
        daily_average: daily_average,
        threshold: threshold,
        spike_factor: spike_factor,
        yesterday_count: yesterday_count,
        hourly_breakdown: hourly_breakdown
      }

      Logger.info(
        "RegistrationSpikeAlert: spike detected — #{today_count} today vs #{:erlang.float_to_binary(daily_average, decimals: 1)} avg (#{:erlang.float_to_binary(spike_factor, decimals: 1)}x), sending alert"
      )

      UserNotifier.deliver_registration_spike_alert(stats, @recipient)
    else
      Logger.info(
        "RegistrationSpikeAlert: no spike — #{today_count} today vs #{:erlang.float_to_binary(daily_average, decimals: 1)} avg, threshold #{:erlang.float_to_binary(threshold, decimals: 1)}"
      )

      :ok
    end
  end
end
