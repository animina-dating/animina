defmodule Animina.AI.HealthAlert do
  @moduledoc """
  Detects when all Ollama instances are unreachable and sends an email alert.

  Called from the Scheduler's maintenance cycle. Tracks downtime in the
  scheduler state and sends at most one alert per 24 hours after 10+ minutes
  of all instances being down.
  """

  require Logger

  alias Animina.Accounts.UserNotifier
  alias Animina.AI
  alias Animina.AI.HealthTracker
  alias Animina.AI.Semaphore

  @alert_threshold_ms 10 * 60 * 1_000
  @cooldown_ms 24 * 60 * 60 * 1_000

  @doc """
  Checks Ollama instance health and sends an alert email if all instances
  have been down for 10+ minutes. Returns updated scheduler state.

  The optional `tracker` argument allows tests to pass a named HealthTracker.
  """
  def check(state, tracker \\ HealthTracker) do
    all_down? = all_instances_down?(tracker)
    state = track_downtime(state, all_down?)

    if should_alert?(state) do
      diagnostics = gather_diagnostics(state, tracker)

      case UserNotifier.deliver_ollama_health_alert(diagnostics) do
        {:ok, _} ->
          Logger.warning("AI.HealthAlert: Sent Ollama health alert email (all instances down)")

        {:error, reason} ->
          Logger.error("AI.HealthAlert: Failed to send health alert: #{inspect(reason)}")
      end

      %{state | last_health_alert_at: System.monotonic_time(:millisecond)}
    else
      state
    end
  end

  defp all_instances_down?(tracker) do
    statuses = HealthTracker.get_all_statuses(tracker)

    case statuses do
      [] -> false
      list -> Enum.all?(list, fn {_url, status} -> status.state == :open end)
    end
  end

  defp track_downtime(state, true) do
    if state.all_down_since do
      state
    else
      %{state | all_down_since: System.monotonic_time(:millisecond)}
    end
  end

  defp track_downtime(state, false) do
    %{state | all_down_since: nil}
  end

  defp should_alert?(%{all_down_since: nil}), do: false

  defp should_alert?(state) do
    now = System.monotonic_time(:millisecond)
    down_duration = now - state.all_down_since

    cooldown_elapsed? =
      case state.last_health_alert_at do
        nil -> true
        ts -> now - ts >= @cooldown_ms
      end

    down_duration >= @alert_threshold_ms and cooldown_elapsed?
  end

  defp gather_diagnostics(state, tracker) do
    now = System.monotonic_time(:millisecond)
    down_minutes = div(now - state.all_down_since, 60_000)

    instance_stats = HealthTracker.get_instance_stats(tracker)
    queue_stats = AI.queue_stats()
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-1, :hour)
    failed_last_hour = AI.count_failed_since(one_hour_ago)

    semaphore_status =
      try do
        Semaphore.status()
      catch
        :exit, _ -> %{active: 0, max: 0, waiting: 0}
      end

    %{
      down_minutes: down_minutes,
      instance_stats: instance_stats,
      queue_stats: queue_stats,
      failed_last_hour: failed_last_hour,
      semaphore: semaphore_status
    }
  end
end
