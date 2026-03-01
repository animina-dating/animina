defmodule Animina.Accounts.RegistrationSpikeAlert do
  @moduledoc """
  Quantum job that checks for registration spikes every 2 hours (06:00-20:00 Berlin).

  Compares today's confirmed registrations against the 30-day rolling daily average.
  When registrations exceed 1.5x the average, sends a statistical overview email.

  Uses escalating thresholds to avoid repeated alerts: after the first alert,
  subsequent alerts are only sent when the spike factor at least doubles.
  """

  require Logger

  alias Animina.Accounts
  alias Animina.Accounts.UserNotifier

  @recipient {"Stefan Wintermeyer", "sw@wintermeyer-consulting.de"}
  @spike_multiplier 1.5
  @pt_key :registration_spike_last_alert
  @escalation_multiplier 2.0

  def run do
    today_count = Accounts.count_confirmed_users_today_berlin()
    daily_average = Accounts.average_daily_confirmed_users_last_30_days()
    threshold = daily_average * @spike_multiplier

    if today_count > 0 and today_count >= threshold do
      spike_factor =
        if daily_average > 0, do: today_count / daily_average, else: today_count / 1.0

      if should_alert?(Date.utc_today(), spike_factor) do
        yesterday_count = Accounts.count_confirmed_users_yesterday_berlin()
        hourly_breakdown = Accounts.confirmed_users_today_by_hour_berlin()

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

        record_alert(Date.utc_today(), spike_factor)
        UserNotifier.deliver_registration_spike_alert(stats, @recipient)
      else
        {_date, last_factor} = last_alert_state()
        needed = last_factor * @escalation_multiplier

        Logger.info(
          "RegistrationSpikeAlert: spike at #{:erlang.float_to_binary(spike_factor, decimals: 1)}x suppressed — need #{:erlang.float_to_binary(needed, decimals: 1)}x to re-alert"
        )

        :ok
      end
    else
      Logger.info(
        "RegistrationSpikeAlert: no spike — #{today_count} today vs #{:erlang.float_to_binary(daily_average, decimals: 1)} avg, threshold #{:erlang.float_to_binary(threshold, decimals: 1)}"
      )

      :ok
    end
  end

  defp should_alert?(today, spike_factor) do
    case last_alert_state() do
      {^today, last_factor} ->
        spike_factor >= last_factor * @escalation_multiplier

      _ ->
        true
    end
  end

  defp last_alert_state do
    :persistent_term.get(@pt_key)
  rescue
    ArgumentError -> {nil, 0.0}
  end

  defp record_alert(date, spike_factor) do
    :persistent_term.put(@pt_key, {date, spike_factor})
  end
end
