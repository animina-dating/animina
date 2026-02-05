defmodule Animina.FeatureFlags.OllamaDebugTest do
  use Animina.DataCase, async: true

  alias Animina.FeatureFlags
  alias Animina.FeatureFlags.OllamaDebugStore

  describe "ollama_debug_display feature flag" do
    setup do
      # Reset the flag state before each test
      FunWithFlags.disable(:ollama_debug_display)
      :ok
    end

    test "ollama_debug_enabled?/0 returns false when disabled" do
      FunWithFlags.disable(:ollama_debug_display)
      assert FeatureFlags.ollama_debug_enabled?() == false
    end

    test "ollama_debug_enabled?/0 returns true when enabled" do
      FunWithFlags.enable(:ollama_debug_display)
      assert FeatureFlags.ollama_debug_enabled?() == true
    end

    test "flag can be toggled" do
      assert FeatureFlags.ollama_debug_enabled?() == false

      FunWithFlags.enable(:ollama_debug_display)
      assert FeatureFlags.ollama_debug_enabled?() == true

      FunWithFlags.disable(:ollama_debug_display)
      assert FeatureFlags.ollama_debug_enabled?() == false
    end
  end

  describe "OllamaDebugStore" do
    setup do
      # Clear any existing entries before each test
      OllamaDebugStore.clear_all()
      :ok
    end

    test "store_call/1 stores a debug entry" do
      entry = %{
        timestamp: DateTime.utc_now(),
        model: "qwen3-vl:8b",
        prompt: "Test prompt",
        images: ["base64data"],
        response: %{"response" => "Test response"},
        server_url: "http://localhost:11434/api",
        duration_ms: 1500,
        photo_id: "test-photo-123"
      }

      assert :ok = OllamaDebugStore.store_call(entry)
    end

    test "get_recent_calls/0 returns recent entries" do
      entry1 = %{
        timestamp: DateTime.utc_now(),
        model: "qwen3-vl:8b",
        prompt: "First call",
        photo_id: "photo-1"
      }

      entry2 = %{
        timestamp: DateTime.utc_now(),
        model: "qwen3-vl:8b",
        prompt: "Second call",
        photo_id: "photo-2"
      }

      OllamaDebugStore.store_call(entry1)
      OllamaDebugStore.store_call(entry2)

      calls = OllamaDebugStore.get_recent_calls()
      assert length(calls) >= 2

      # Most recent should be first
      [most_recent | _] = calls
      assert most_recent.prompt == "Second call"
    end

    test "get_recent_calls/1 limits the number of entries" do
      for i <- 1..5 do
        OllamaDebugStore.store_call(%{
          timestamp: DateTime.utc_now(),
          model: "qwen3-vl:8b",
          prompt: "Call #{i}",
          photo_id: "photo-#{i}"
        })
      end

      calls = OllamaDebugStore.get_recent_calls(3)
      assert length(calls) == 3
    end

    test "clear_all/0 removes all entries" do
      OllamaDebugStore.store_call(%{
        timestamp: DateTime.utc_now(),
        prompt: "Test",
        photo_id: "test"
      })

      OllamaDebugStore.clear_all()
      assert OllamaDebugStore.get_recent_calls() == []
    end

    test "old entries are automatically cleaned up" do
      # Store entries with old timestamps (simulated by setting low max_age)
      entry = %{
        timestamp: DateTime.utc_now() |> DateTime.add(-3600, :second),
        prompt: "Old call",
        photo_id: "old-photo"
      }

      OllamaDebugStore.store_call(entry)

      # Manually trigger cleanup with 0 max age
      OllamaDebugStore.cleanup(0)

      calls = OllamaDebugStore.get_recent_calls()
      assert calls == []
    end
  end
end
