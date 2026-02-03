defmodule Animina.Photos.OllamaClientTest do
  use ExUnit.Case, async: false

  alias Animina.Photos.OllamaClient
  alias Animina.Photos.OllamaHealthTracker

  @test_url_1 "http://server1:11434/api"
  @test_url_2 "http://server2:11434/api"

  setup do
    # Start a fresh tracker for each test
    start_supervised!(
      {OllamaHealthTracker,
       name: :test_ollama_tracker,
       threshold: 3,
       reset_ms: 100,
       instances: [@test_url_1, @test_url_2]}
    )

    %{tracker: :test_ollama_tracker}
  end

  describe "failover_eligible_error?/1" do
    test "connection errors are failover-eligible" do
      assert OllamaClient.failover_eligible_error?(:econnrefused)
      assert OllamaClient.failover_eligible_error?(:timeout)
      assert OllamaClient.failover_eligible_error?(:closed)
      assert OllamaClient.failover_eligible_error?(:connect_timeout)
      assert OllamaClient.failover_eligible_error?(:ehostunreach)
      assert OllamaClient.failover_eligible_error?(:enetunreach)
    end

    test "HTTP 5xx errors are failover-eligible" do
      assert OllamaClient.failover_eligible_error?({:http_error, 502})
      assert OllamaClient.failover_eligible_error?({:http_error, 503})
      assert OllamaClient.failover_eligible_error?({:http_error, 504})
    end

    test "HTTP 429 (rate limit) is failover-eligible" do
      assert OllamaClient.failover_eligible_error?({:http_error, 429})
    end

    test "HTTP 4xx client errors are NOT failover-eligible" do
      refute OllamaClient.failover_eligible_error?({:http_error, 400})
      refute OllamaClient.failover_eligible_error?({:http_error, 404})
      refute OllamaClient.failover_eligible_error?({:http_error, 413})
    end

    test "other errors are NOT failover-eligible" do
      refute OllamaClient.failover_eligible_error?(:unknown_error)
      refute OllamaClient.failover_eligible_error?({:invalid, :response})
    end
  end

  describe "parse_error/1" do
    test "extracts status code from Mint.HTTPError" do
      error = %Mint.HTTPError{reason: {:status, 503}}
      assert OllamaClient.parse_error(error) == {:http_error, 503}
    end

    test "handles :timeout as-is" do
      assert OllamaClient.parse_error(:timeout) == :timeout
    end

    test "handles connection refused" do
      assert OllamaClient.parse_error(:econnrefused) == :econnrefused
    end

    test "wraps unknown errors" do
      assert OllamaClient.parse_error("some string") == {:unknown, "some string"}
    end
  end

  describe "get_instances_to_try/1" do
    test "returns instances sorted by priority", %{tracker: tracker} do
      instances = [
        %{url: @test_url_2, timeout: 120_000, priority: 2},
        %{url: @test_url_1, timeout: 120_000, priority: 1}
      ]

      result = OllamaClient.get_instances_to_try(instances, tracker)

      assert length(result) == 2
      assert hd(result).url == @test_url_1
    end

    test "excludes instances with open circuits", %{tracker: tracker} do
      # Open circuit for url_1
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)

      instances = [
        %{url: @test_url_1, timeout: 120_000, priority: 1},
        %{url: @test_url_2, timeout: 120_000, priority: 2}
      ]

      result = OllamaClient.get_instances_to_try(instances, tracker)

      assert length(result) == 1
      assert hd(result).url == @test_url_2
    end

    test "returns all instances if all circuits open (last resort)", %{tracker: tracker} do
      # Open both circuits
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_1, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_2, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_2, :timeout)
      OllamaHealthTracker.record_failure(tracker, @test_url_2, :timeout)

      instances = [
        %{url: @test_url_1, timeout: 120_000, priority: 1},
        %{url: @test_url_2, timeout: 120_000, priority: 2}
      ]

      # All circuits open, but we should still return instances as last resort
      result = OllamaClient.get_instances_to_try(instances, tracker)

      # Returns all instances sorted by priority as fallback
      assert length(result) == 2
    end
  end

  describe "backward compatibility" do
    test "works with single URL config" do
      # This tests the config helper in Photos context
      # Single URL should be converted to instances list
      instances = Animina.Photos.ollama_instances()

      assert is_list(instances)
      assert instances != []
      assert hd(instances).url != nil
      assert hd(instances).priority == 1
    end
  end

  describe "calculate_request_timeout/2" do
    test "uses instance timeout when less than remaining time" do
      instance = %{url: @test_url_1, timeout: 120_000, priority: 1}
      deadline = System.monotonic_time(:millisecond) + 300_000

      result = OllamaClient.calculate_request_timeout(instance, deadline)

      assert result == 120_000
    end

    test "uses remaining time when less than instance timeout" do
      instance = %{url: @test_url_1, timeout: 120_000, priority: 1}
      deadline = System.monotonic_time(:millisecond) + 50_000

      result = OllamaClient.calculate_request_timeout(instance, deadline)

      assert result <= 50_000
      assert result > 0
    end

    test "returns minimum 1000ms even if time is nearly up" do
      instance = %{url: @test_url_1, timeout: 120_000, priority: 1}
      deadline = System.monotonic_time(:millisecond) + 100

      result = OllamaClient.calculate_request_timeout(instance, deadline)

      assert result == 1000
    end
  end
end
