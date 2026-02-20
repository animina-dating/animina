defmodule Animina.WingmanTest do
  use Animina.DataCase, async: true

  alias Animina.Wingman

  import Animina.AccountsFixtures

  describe "gather_context/3" do
    test "includes basic user data" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])

      assert context.user.display_name == "Alice"
      assert context.other_user.display_name == "Bob"
      assert is_binary(context.conversation_state) or is_nil(context.conversation_state)
    end

    test "includes conversation state summary" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      # Empty conversation
      context = Wingman.gather_context(user, other, [])
      assert context.conversation_state == "new"
    end

    test "includes overlap without red_white" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      context = Wingman.gather_context(user, other, [])

      assert is_map(context.overlap)
      assert Map.has_key?(context.overlap, :shared_traits)
      assert Map.has_key?(context.overlap, :compatible_values)
      # Should not include red_white overlap
      refute Map.has_key?(context.overlap, :red_white)
      refute Map.has_key?(context.overlap, :dealbreakers)
    end

    test "returns lists for stories and photo descriptions" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      context = Wingman.gather_context(user, other, [])

      assert is_list(context.user.stories)
      assert is_list(context.user.photo_descriptions)
      assert is_list(context.user.published_flags)
    end
  end

  describe "build_prompt/2" do
    test "produces a non-empty prompt string" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert is_binary(prompt)
      assert String.length(prompt) > 50
      assert prompt =~ "Alice" or prompt =~ "About you"
      assert prompt =~ "Bob" or prompt =~ "About"
      assert prompt =~ "JSON"
    end

    test "builds German prompt when language is de" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Dating-Coach"
    end
  end

  describe "parse_suggestions/1" do
    test "parses valid JSON array" do
      raw = ~s([{"text": "Ask about hiking!", "hook": "You both love nature"}])

      assert {:ok, suggestions} = Wingman.parse_suggestions(raw)
      assert length(suggestions) == 1
      assert hd(suggestions)["text"] == "Ask about hiking!"
      assert hd(suggestions)["hook"] == "You both love nature"
    end

    test "handles response with surrounding text" do
      raw = """
      Here are some suggestions:
      [{"text": "Tip 1", "hook": "Reason 1"}, {"text": "Tip 2", "hook": "Reason 2"}]
      Hope this helps!
      """

      assert {:ok, suggestions} = Wingman.parse_suggestions(raw)
      assert length(suggestions) == 2
    end

    test "limits to 3 suggestions" do
      raw =
        Jason.encode!([
          %{"text" => "Tip 1", "hook" => "R1"},
          %{"text" => "Tip 2", "hook" => "R2"},
          %{"text" => "Tip 3", "hook" => "R3"},
          %{"text" => "Tip 4", "hook" => "R4"}
        ])

      assert {:ok, suggestions} = Wingman.parse_suggestions(raw)
      assert length(suggestions) == 3
    end

    test "handles malformed JSON" do
      assert {:error, :parse_failed} = Wingman.parse_suggestions("not json at all")
    end

    test "handles empty response" do
      assert {:error, :parse_failed} = Wingman.parse_suggestions("")
    end

    test "handles nil response" do
      assert {:error, :parse_failed} = Wingman.parse_suggestions(nil)
    end

    test "handles empty array" do
      assert {:error, :parse_failed} = Wingman.parse_suggestions("[]")
    end

    test "filters out suggestions with empty text" do
      raw = Jason.encode!([%{"text" => "", "hook" => "R1"}, %{"text" => "Tip", "hook" => "R2"}])

      assert {:ok, suggestions} = Wingman.parse_suggestions(raw)
      assert length(suggestions) == 1
      assert hd(suggestions)["text"] == "Tip"
    end
  end

  describe "context_hash/1" do
    test "returns a consistent hash for the same context" do
      context = %{user: %{name: "Alice"}, other_user: %{name: "Bob"}}

      hash1 = Wingman.context_hash(context)
      hash2 = Wingman.context_hash(context)

      assert hash1 == hash2
      assert is_binary(hash1)
      assert String.length(hash1) == 16
    end

    test "returns different hash for different context" do
      context1 = %{user: %{name: "Alice"}, other_user: %{name: "Bob"}}
      context2 = %{user: %{name: "Alice"}, other_user: %{name: "Carol"}}

      assert Wingman.context_hash(context1) != Wingman.context_hash(context2)
    end
  end

  describe "suggestion_topic/2" do
    test "returns a formatted topic string" do
      topic = Wingman.suggestion_topic("conv-123", "user-456")
      assert topic == "wingman:conv-123:user-456"
    end
  end
end
