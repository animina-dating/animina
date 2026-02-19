defmodule Animina.AI.HealthAlertTest do
  use Animina.DataCase, async: true

  alias Animina.AI.HealthAlert
  alias Animina.AI.HealthTracker

  defp start_tracker(instances) do
    # Start a named HealthTracker with pre-configured instances
    name = :"health_tracker_#{System.unique_integer([:positive])}"

    instance_data = Enum.map(instances, fn {url, state} -> {url, state, ["gpu"]} end)

    {:ok, _pid} =
      HealthTracker.start_link(
        name: name,
        instances: Enum.map(instance_data, fn {url, _state, tags} -> {url, tags} end),
        threshold: 1
      )

    # Simulate failures to open circuits where needed
    for {url, :open, _tags} <- instance_data do
      HealthTracker.record_failure(name, url, :test_failure)
    end

    name
  end

  defp base_state do
    %{
      all_down_since: nil,
      last_health_alert_at: nil,
      poll_interval: 5000
    }
  end

  describe "check/1" do
    test "returns unchanged state when instances are healthy" do
      tracker =
        start_tracker([
          {"http://gpu1:11434", :closed},
          {"http://gpu2:11434", :closed}
        ])

      state = base_state()
      result = HealthAlert.check(state, tracker)

      assert result.all_down_since == nil
      assert result.last_health_alert_at == nil
    end

    test "sets all_down_since when all instances go down" do
      tracker =
        start_tracker([
          {"http://gpu1:11434", :open},
          {"http://gpu2:11434", :open}
        ])

      now = System.monotonic_time(:millisecond)
      result = HealthAlert.check(base_state(), tracker)

      assert result.all_down_since != nil
      assert result.all_down_since >= now
    end

    test "clears all_down_since when instances recover" do
      tracker =
        start_tracker([
          {"http://gpu1:11434", :closed},
          {"http://gpu2:11434", :closed}
        ])

      state = %{base_state() | all_down_since: System.monotonic_time(:millisecond) - 60_000}
      result = HealthAlert.check(state, tracker)

      assert result.all_down_since == nil
    end

    test "does not alert before 10 minutes" do
      tracker = start_tracker([{"http://gpu1:11434", :open}])

      # Down for only 5 minutes
      state = %{
        base_state()
        | all_down_since: System.monotonic_time(:millisecond) - 5 * 60 * 1_000
      }

      result = HealthAlert.check(state, tracker)

      assert result.all_down_since != nil
      assert result.last_health_alert_at == nil
    end

    test "sends alert after 10+ minutes of downtime" do
      tracker = start_tracker([{"http://gpu1:11434", :open}])

      # Down for 11 minutes, never alerted
      state = %{
        base_state()
        | all_down_since: System.monotonic_time(:millisecond) - 11 * 60 * 1_000
      }

      result = HealthAlert.check(state, tracker)

      assert result.last_health_alert_at != nil
      assert is_integer(result.last_health_alert_at)
    end

    test "does not send a second alert within 24 hours" do
      tracker = start_tracker([{"http://gpu1:11434", :open}])

      now = System.monotonic_time(:millisecond)

      # Down for 11 minutes, but alert was sent 1 hour ago
      state = %{
        base_state()
        | all_down_since: now - 11 * 60 * 1_000,
          last_health_alert_at: now - 60 * 60 * 1_000
      }

      result = HealthAlert.check(state, tracker)

      # last_health_alert_at should NOT have changed
      assert result.last_health_alert_at == state.last_health_alert_at
    end

    test "sends alert again after 24 hour cooldown" do
      tracker = start_tracker([{"http://gpu1:11434", :open}])

      now = System.monotonic_time(:millisecond)

      # Down for 25 hours, last alert was 25 hours ago
      state = %{
        base_state()
        | all_down_since: now - 25 * 60 * 60 * 1_000,
          last_health_alert_at: now - 25 * 60 * 60 * 1_000
      }

      result = HealthAlert.check(state, tracker)

      assert result.last_health_alert_at > state.last_health_alert_at
    end
  end
end
