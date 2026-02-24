defmodule Animina.AI.GreetingGuardTest do
  use Animina.DataCase, async: false

  alias Animina.AI.GreetingGuard

  # Minimal structs mimicking the fields used by should_check?/4
  defp male_sender(opts \\ []) do
    %{
      gender: "male",
      wingman_enabled: Keyword.get(opts, :wingman_enabled, true)
    }
  end

  defp female_recipient, do: %{gender: "female"}
  defp male_recipient, do: %{gender: "male"}
  defp female_sender, do: %{gender: "female", wingman_enabled: true}

  describe "should_check?/4 — pre-filter (no AI)" do
    test "returns true for male→female, empty messages, short content" do
      FunWithFlags.enable(:wingman)
      assert GreetingGuard.should_check?(male_sender(), female_recipient(), "Hi!", [])
      FunWithFlags.disable(:wingman)
    end

    test "returns true for short greeting variants" do
      FunWithFlags.enable(:wingman)

      assert GreetingGuard.should_check?(male_sender(), female_recipient(), "Hello", [])
      assert GreetingGuard.should_check?(male_sender(), female_recipient(), "Hallo Susan!", [])
      assert GreetingGuard.should_check?(male_sender(), female_recipient(), "Hey there", [])
      assert GreetingGuard.should_check?(male_sender(), female_recipient(), "Na?", [])

      FunWithFlags.disable(:wingman)
    end

    test "returns false for female→male" do
      refute GreetingGuard.should_check?(female_sender(), male_recipient(), "Hi!", [])
    end

    test "returns false for male→male" do
      refute GreetingGuard.should_check?(male_sender(), male_recipient(), "Hi!", [])
    end

    test "returns false for female→female" do
      refute GreetingGuard.should_check?(female_sender(), female_recipient(), "Hi!", [])
    end

    test "returns false when there are existing messages" do
      messages = [%{id: "some-msg"}]
      refute GreetingGuard.should_check?(male_sender(), female_recipient(), "Hi!", messages)
    end

    test "returns false for long messages (>= 25 chars)" do
      long = "Hey, I noticed you like hiking too! Want to chat about trails?"
      refute GreetingGuard.should_check?(male_sender(), female_recipient(), long, [])
    end

    test "returns false for multi-line messages" do
      multi = "Hi!\nHow are you?"
      refute GreetingGuard.should_check?(male_sender(), female_recipient(), multi, [])
    end

    test "returns false when wingman is disabled on sender" do
      sender = male_sender(wingman_enabled: false)
      refute GreetingGuard.should_check?(sender, female_recipient(), "Hi!", [])
    end

    test "returns false when wingman feature flag is off" do
      FunWithFlags.disable(:wingman)
      refute GreetingGuard.should_check?(male_sender(), female_recipient(), "Hi!", [])
    end

    test "returns false for whitespace-only content" do
      refute GreetingGuard.should_check?(male_sender(), female_recipient(), "   ", [])
    end

    test "returns false for empty content" do
      refute GreetingGuard.should_check?(male_sender(), female_recipient(), "", [])
    end

    test "trims content before checking length" do
      FunWithFlags.enable(:wingman)
      assert GreetingGuard.should_check?(male_sender(), female_recipient(), "  Hi!  ", [])
      FunWithFlags.disable(:wingman)
    end

    test "returns false for diverse gender" do
      diverse_sender = %{gender: "diverse", wingman_enabled: true}
      refute GreetingGuard.should_check?(diverse_sender, female_recipient(), "Hi!", [])
    end
  end

  describe "parse_response/1" do
    test "extracts is_generic_greeting true from JSON" do
      response = ~s|{"is_generic_greeting": true}|
      assert GreetingGuard.parse_response(response) == {:ok, true}
    end

    test "extracts is_generic_greeting false from JSON" do
      response = ~s|{"is_generic_greeting": false}|
      assert GreetingGuard.parse_response(response) == {:ok, false}
    end

    test "handles JSON after think tags" do
      response = ~s|<think>\nLet me check...\n</think>\n{"is_generic_greeting": true}|
      assert GreetingGuard.parse_response(response) == {:ok, true}
    end

    test "returns error for unparseable response" do
      assert GreetingGuard.parse_response("something random") == {:error, :unparseable}
    end

    test "returns error for nil" do
      assert GreetingGuard.parse_response(nil) == {:error, :unparseable}
    end

    test "returns error for empty string" do
      assert GreetingGuard.parse_response("") == {:error, :unparseable}
    end
  end
end
