defmodule Animina.Photos.OllamaHealthTrackerTest do
  use ExUnit.Case, async: false

  alias Animina.Photos.OllamaHealthTracker

  @test_url_1 "http://server1:11434/api"
  @test_url_2 "http://server2:11434/api"

  setup do
    # Start a fresh tracker for each test
    start_supervised!(
      {OllamaHealthTracker,
       name: :test_tracker, threshold: 3, reset_ms: 100, instances: [@test_url_1, @test_url_2]}
    )

    %{tracker: :test_tracker}
  end

  describe "get_all_statuses/1" do
    test "returns all instances with :closed status initially", %{tracker: tracker} do
      statuses = OllamaHealthTracker.get_all_statuses(tracker)

      assert length(statuses) == 2
      assert Enum.all?(statuses, fn {_url, status} -> status.state == :closed end)
      assert Enum.all?(statuses, fn {_url, status} -> status.failure_count == 0 end)
    end
  end

  describe "record_success/2" do
    test "keeps circuit closed and resets failure count", %{tracker: tracker} do
      # Record some failures first
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      # Verify failures recorded
      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.failure_count == 2

      # Record success
      OllamaHealthTracker.record_success(tracker, @test_url_1)

      # Verify reset
      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :closed
      assert status.failure_count == 0
    end

    test "closes an open circuit on success", %{tracker: tracker} do
      # Force circuit to open
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :open

      # Record success to close
      OllamaHealthTracker.record_success(tracker, @test_url_1)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :closed
      assert status.failure_count == 0
    end
  end

  describe "record_failure/3" do
    test "increments failure count", %{tracker: tracker} do
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :connection_refused)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.failure_count == 1
    end

    test "opens circuit after reaching threshold", %{tracker: tracker} do
      # First two failures keep circuit closed
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :connection_refused)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :closed
      assert status.failure_count == 2

      # Third failure opens circuit
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :open
      assert status.failure_count == 3
    end

    test "tracks failures independently per URL", %{tracker: tracker} do
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_2, :timeout)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status1} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      {_url, status2} = Enum.find(statuses, fn {url, _} -> url == @test_url_2 end)

      assert status1.failure_count == 2
      assert status2.failure_count == 1
    end
  end

  describe "get_healthy_instances/1" do
    test "returns all instances when all circuits are closed", %{tracker: tracker} do
      healthy = OllamaHealthTracker.get_healthy_instances(tracker)
      assert length(healthy) == 2
    end

    test "excludes instances with open circuits", %{tracker: tracker} do
      # Open circuit for url_1
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      healthy = OllamaHealthTracker.get_healthy_instances(tracker)
      assert length(healthy) == 1
      assert hd(healthy) == @test_url_2
    end

    test "includes half-open instances", %{tracker: tracker} do
      # Open circuit
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      # Wait for reset timeout (100ms in test)
      Process.sleep(150)

      # Trigger half-open by calling get_healthy_instances
      healthy = OllamaHealthTracker.get_healthy_instances(tracker)

      # Should include the now half-open instance
      assert length(healthy) == 2

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :half_open
    end
  end

  describe "circuit breaker state transitions" do
    test "closed -> open -> half_open -> closed on success", %{tracker: tracker} do
      # Start closed
      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :closed

      # Transition to open
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :open

      # Wait for cooldown and trigger half-open check
      Process.sleep(150)
      _healthy = OllamaHealthTracker.get_healthy_instances(tracker)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :half_open

      # Success closes circuit
      OllamaHealthTracker.record_success(tracker, @test_url_1)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :closed
    end

    test "half_open -> open on failure", %{tracker: tracker} do
      # Open circuit and wait for half-open
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      Process.sleep(150)
      _healthy = OllamaHealthTracker.get_healthy_instances(tracker)

      # Verify half-open
      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :half_open

      # Failure during half-open reopens circuit
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      {_url, status} = Enum.find(statuses, fn {url, _} -> url == @test_url_1 end)
      assert status.state == :open
    end
  end

  describe "unknown instance handling" do
    test "record_success for unknown URL does nothing", %{tracker: tracker} do
      # Should not crash
      :ok = OllamaHealthTracker.record_success(tracker, "http://unknown:11434/api")

      # Original instances should be unchanged
      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      assert length(statuses) == 2
    end

    test "record_failure for unknown URL does nothing", %{tracker: tracker} do
      # Should not crash
      :ok = OllamaHealthTracker.record_failure(tracker, "http://unknown:11434/api", :timeout)

      # Original instances should be unchanged
      statuses = OllamaHealthTracker.get_all_statuses(tracker)
      assert length(statuses) == 2
    end
  end
end
