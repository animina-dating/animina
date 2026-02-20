defmodule Animina.WingmanTest do
  use Animina.DataCase, async: true

  alias Animina.Messaging
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

    test "includes user_ratings in context" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      context = Wingman.gather_context(user, other, [])

      assert is_list(context.user_ratings)
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

    test "builds German prompt with Wingman persona" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Wingman"
      refute prompt =~ "Dating-Coach"
    end

    test "builds English prompt with Wingman persona" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "wingman"
      refute prompt =~ "dating coach"
    end

    test "includes user age in system instruction" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      # The user's age should appear in the prompt
      if context.user.age do
        assert prompt =~ "#{context.user.age}"
      end
    end
  end

  describe "build_prompt/3 with style" do
    test "casual prompt contains wingman persona (EN)" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en", "casual")

      assert prompt =~ "wingman"
    end

    test "casual prompt contains Wingman persona (DE)" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de", "casual")

      assert prompt =~ "Wingman"
    end

    test "funny prompt contains humor-related terms (EN)" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en", "funny")

      assert prompt =~ "witty" or prompt =~ "humor"
    end

    test "funny prompt contains humor-related terms (DE)" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de", "funny")

      assert prompt =~ "witzig" or prompt =~ "Humor"
    end

    test "empathetic prompt contains empathy-related terms (EN)" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en", "empathetic")

      assert prompt =~ "warm" or prompt =~ "thoughtful"
    end

    test "empathetic prompt contains empathy-related terms (DE)" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de", "empathetic")

      assert prompt =~ "einfühlsam" or prompt =~ "warmherzig"
    end

    test "build_prompt/2 without style produces same result as casual" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt_default = Wingman.build_prompt(context, "en")
      prompt_casual = Wingman.build_prompt(context, "en", "casual")

      assert prompt_default == prompt_casual
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

    test "limits to 2 suggestions" do
      raw =
        Jason.encode!([
          %{"text" => "Tip 1", "hook" => "R1"},
          %{"text" => "Tip 2", "hook" => "R2"},
          %{"text" => "Tip 3", "hook" => "R3"},
          %{"text" => "Tip 4", "hook" => "R4"}
        ])

      assert {:ok, suggestions} = Wingman.parse_suggestions(raw)
      assert length(suggestions) == 2
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

  describe "wingman feedback" do
    setup do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")
      {:ok, conversation} = Messaging.get_or_create_conversation(user.id, other.id)

      suggestion_data = %{
        text: "Ask about their hiking photos",
        hook: "You both love nature"
      }

      %{user: user, conversation: conversation, suggestion_data: suggestion_data}
    end

    test "toggle_feedback/5 creates a new feedback record", %{
      user: user,
      conversation: conversation,
      suggestion_data: suggestion_data
    } do
      assert {:ok, :created, feedback} =
               Wingman.toggle_feedback(user.id, conversation.id, 0, 1, suggestion_data)

      assert feedback.user_id == user.id
      assert feedback.conversation_id == conversation.id
      assert feedback.suggestion_index == 0
      assert feedback.value == 1
      assert feedback.suggestion_text == "Ask about their hiking photos"
      assert feedback.suggestion_hook == "You both love nature"
    end

    test "toggle_feedback/5 toggles off when same value", %{
      user: user,
      conversation: conversation,
      suggestion_data: suggestion_data
    } do
      {:ok, :created, _} =
        Wingman.toggle_feedback(user.id, conversation.id, 0, 1, suggestion_data)

      assert {:ok, :removed} =
               Wingman.toggle_feedback(user.id, conversation.id, 0, 1, suggestion_data)

      # Should be gone
      assert Wingman.get_feedback_for_suggestions(user.id, conversation.id) == %{}
    end

    test "toggle_feedback/5 switches value when different", %{
      user: user,
      conversation: conversation,
      suggestion_data: suggestion_data
    } do
      {:ok, :created, _} =
        Wingman.toggle_feedback(user.id, conversation.id, 0, 1, suggestion_data)

      assert {:ok, :switched, feedback} =
               Wingman.toggle_feedback(user.id, conversation.id, 0, -1, suggestion_data)

      assert feedback.value == -1
    end

    test "get_feedback_for_suggestions/2 returns index => value map", %{
      user: user,
      conversation: conversation,
      suggestion_data: suggestion_data
    } do
      Wingman.toggle_feedback(user.id, conversation.id, 0, 1, suggestion_data)

      Wingman.toggle_feedback(user.id, conversation.id, 1, -1, %{
        text: "Comment on their city",
        hook: "Local connection"
      })

      result = Wingman.get_feedback_for_suggestions(user.id, conversation.id)
      assert result == %{0 => 1, 1 => -1}
    end

    test "recent_feedback/1 returns last 10 ordered by recency", %{
      user: user,
      suggestion_data: suggestion_data
    } do
      # Create 12 feedbacks across different conversations
      for i <- 1..12 do
        other = user_fixture(display_name: "User#{i}", language: "en")
        {:ok, conv} = Messaging.get_or_create_conversation(user.id, other.id)
        Wingman.toggle_feedback(user.id, conv.id, 0, 1, suggestion_data)
      end

      feedbacks = Wingman.recent_feedback(user.id)
      assert length(feedbacks) == 10
    end

    test "recent_feedback/1 returns empty list when none" do
      user = user_fixture(display_name: "Lonely", language: "en")
      assert Wingman.recent_feedback(user.id) == []
    end
  end

  describe "feedback_section/2" do
    test "formats liked/disliked for EN" do
      feedbacks = [
        %{value: 1, suggestion_text: "Ask about their hiking photos"},
        %{value: -1, suggestion_text: "Comment on their city"}
      ]

      section = Wingman.feedback_section(feedbacks, "en")
      assert section =~ "Previous feedback"
      assert section =~ "Liked"
      assert section =~ "Ask about their hiking photos"
      assert section =~ "Disliked"
      assert section =~ "Comment on their city"
    end

    test "formats liked/disliked for DE" do
      feedbacks = [
        %{value: 1, suggestion_text: "Frag nach den Wanderfotos"},
        %{value: -1, suggestion_text: "Kommentiere die Stadt"}
      ]

      section = Wingman.feedback_section(feedbacks, "de")
      assert section =~ "Bisheriges Feedback"
      assert section =~ "Gefallen"
      assert section =~ "Frag nach den Wanderfotos"
      assert section =~ "Nicht gefallen"
      assert section =~ "Kommentiere die Stadt"
    end

    test "returns empty string when no feedback" do
      assert Wingman.feedback_section([], "en") == ""
    end
  end

  describe "build_prompt/4 with feedback" do
    test "includes feedback section when feedback provided" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])

      feedback = [
        %{value: 1, suggestion_text: "Ask about hiking"},
        %{value: -1, suggestion_text: "Mention the weather"}
      ]

      prompt = Wingman.build_prompt(context, "en", "casual", feedback)
      assert prompt =~ "Previous feedback"
      assert prompt =~ "Ask about hiking"
      assert prompt =~ "Mention the weather"
    end

    test "build_prompt/3 without feedback produces same as build_prompt/4 with empty list" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt_without = Wingman.build_prompt(context, "en", "casual")
      prompt_with_empty = Wingman.build_prompt(context, "en", "casual", [])

      assert prompt_without == prompt_with_empty
    end
  end

  describe "wingman reload / regeneration" do
    setup do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")
      {:ok, conversation} = Messaging.get_or_create_conversation(user.id, other.id)

      %{user: user, other: other, conversation: conversation}
    end

    test "get_regeneration_count/2 defaults to 0 when no record", %{
      user: user,
      conversation: conversation
    } do
      assert Wingman.get_regeneration_count(conversation.id, user.id) == 0
    end

    test "can_reload?/2 returns true when count is below max", %{
      user: user,
      conversation: conversation
    } do
      assert Wingman.can_reload?(conversation.id, user.id)
    end

    test "max_reloads/0 returns 3" do
      assert Wingman.max_reloads() == 3
    end

    test "refresh_suggestions with increment_count: true increments regeneration_count", %{
      user: user,
      other: other,
      conversation: conversation
    } do
      # Create initial suggestion record
      Wingman.get_or_generate_suggestions(conversation.id, user.id, other.id)

      # Refresh with increment
      Wingman.refresh_suggestions(conversation.id, user.id, other.id, increment_count: true)
      assert Wingman.get_regeneration_count(conversation.id, user.id) == 1

      # Refresh again with increment
      Wingman.refresh_suggestions(conversation.id, user.id, other.id, increment_count: true)
      assert Wingman.get_regeneration_count(conversation.id, user.id) == 2
    end

    test "refresh_suggestions with increment_count: false does not increment", %{
      user: user,
      other: other,
      conversation: conversation
    } do
      # Create initial suggestion record
      Wingman.get_or_generate_suggestions(conversation.id, user.id, other.id)

      # Refresh without increment (style change)
      Wingman.refresh_suggestions(conversation.id, user.id, other.id, increment_count: false)
      assert Wingman.get_regeneration_count(conversation.id, user.id) == 0
    end

    test "can_reload?/2 returns false when at max reloads", %{
      user: user,
      other: other,
      conversation: conversation
    } do
      # Create initial suggestion record
      Wingman.get_or_generate_suggestions(conversation.id, user.id, other.id)

      # Increment to max
      for _ <- 1..3 do
        Wingman.refresh_suggestions(conversation.id, user.id, other.id, increment_count: true)
      end

      refute Wingman.can_reload?(conversation.id, user.id)
    end

    test "clear_feedback_for_conversation/2 deletes feedback for conversation", %{
      user: user,
      conversation: conversation
    } do
      suggestion_data = %{text: "Test suggestion", hook: "Test hook"}
      Wingman.toggle_feedback(user.id, conversation.id, 0, 1, suggestion_data)

      assert Wingman.get_feedback_for_suggestions(user.id, conversation.id) != %{}

      Wingman.clear_feedback_for_conversation(user.id, conversation.id)

      assert Wingman.get_feedback_for_suggestions(user.id, conversation.id) == %{}
    end
  end
end
