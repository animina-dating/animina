defmodule Animina.Photos.OllamaWarmupTest do
  use ExUnit.Case, async: true

  alias Animina.Photos.OllamaWarmup

  describe "warmup_all/0" do
    test "does not crash when Ollama is unavailable" do
      # This test verifies that the warmup function handles errors gracefully
      # when Ollama instances are not reachable (typical in test environment)
      assert :ok = OllamaWarmup.warmup_all()
    end
  end
end
