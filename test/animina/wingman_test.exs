defmodule Animina.WingmanTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.Messaging
  alias Animina.Wingman

  import Animina.AccountsFixtures

  describe "wingman_changeset/2" do
    test "valid changeset with wingman_enabled = false" do
      user = user_fixture(language: "en")
      changeset = User.wingman_changeset(user, %{wingman_enabled: false})
      assert changeset.valid?
    end

    test "valid changeset with wingman_enabled = true" do
      user = user_fixture(language: "en")
      changeset = User.wingman_changeset(user, %{wingman_enabled: true})
      assert changeset.valid?
    end

    test "changeset with empty attrs keeps existing value" do
      user = user_fixture(language: "en")
      changeset = User.wingman_changeset(user, %{})
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :wingman_enabled) == true
    end
  end

  describe "update_wingman_enabled/2" do
    test "disables wingman for a user" do
      user = user_fixture(language: "en")
      assert user.wingman_enabled == true

      {:ok, updated} = Accounts.update_wingman_enabled(user, %{wingman_enabled: false})
      assert updated.wingman_enabled == false
    end

    test "re-enables wingman for a user" do
      user = user_fixture(language: "en")
      {:ok, user} = Accounts.update_wingman_enabled(user, %{wingman_enabled: false})

      {:ok, updated} = Accounts.update_wingman_enabled(user, %{wingman_enabled: true})
      assert updated.wingman_enabled == true
    end
  end

  describe "gather_context/3" do
    test "includes basic user data" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])

      assert context.user.display_name == "Alice"
      assert context.other_user.display_name == "Bob"
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
      assert Map.has_key?(context.overlap, :shared_traits_public)
      assert Map.has_key?(context.overlap, :shared_traits_private)
      assert Map.has_key?(context.overlap, :compatible_values)
      # Should not include red_white overlap
      refute Map.has_key?(context.overlap, :red_white)
      refute Map.has_key?(context.overlap, :dealbreakers)
    end

    test "returns lists for stories and flag data" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      context = Wingman.gather_context(user, other, [])

      assert is_list(context.user.stories)
      assert is_list(context.user.white_flags_published)
      assert is_list(context.user.white_flags_private)
      assert is_list(context.user.green_flags)
    end

    test "includes is_wildcard in context" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      context = Wingman.gather_context(user, other, [])

      assert is_boolean(context.is_wildcard)
    end
  end

  describe "gather_context/3 enriched fields" do
    test "includes gender and height in user data" do
      user = user_fixture(display_name: "Aisha", gender: "female", height: 170, language: "en")
      other = user_fixture(display_name: "Tim", gender: "male", height: 185, language: "en")

      context = Wingman.gather_context(user, other, [])

      assert context.user.gender == "female"
      assert context.user.height == 170
      assert context.other_user.gender == "male"
      assert context.other_user.height == 185
    end

    test "includes search preferences" do
      user = user_fixture(display_name: "Aisha", language: "en")
      other = user_fixture(display_name: "Tim", language: "en")

      context = Wingman.gather_context(user, other, [])

      assert is_integer(context.user.partner_age_min)
      assert is_integer(context.user.partner_age_max)
      assert is_integer(context.user.partner_height_min)
      assert is_integer(context.user.partner_height_max)
      assert is_integer(context.user.search_radius)
    end

    test "includes distance_km (same zip = 0)" do
      user = user_fixture(display_name: "Aisha", language: "en")
      other = user_fixture(display_name: "Tim", language: "en")

      context = Wingman.gather_context(user, other, [])

      # Both fixtures use zip 10115, so distance should be 0
      assert context.distance_km == 0
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
      assert prompt =~ "Alice (your user)"
      assert prompt =~ "Bob (the other person)"
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

    test "builds English prompt with wingman persona" do
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

  describe "build_prompt pronoun and enriched context" do
    test "German prompt uses 'ihn' when other is male" do
      user = user_fixture(display_name: "Aisha", gender: "female", language: "de")
      other = user_fixture(display_name: "Tim", gender: "male", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "ihn"
      refute prompt =~ "Sprich sie doch"
    end

    test "German prompt uses 'sie' when other is female" do
      user = user_fixture(display_name: "Tim", gender: "male", language: "de")
      other = user_fixture(display_name: "Aisha", gender: "female", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Sprich sie doch"
    end

    test "English prompt uses 'him' when other is male" do
      user = user_fixture(display_name: "Aisha", gender: "female", language: "en")
      other = user_fixture(display_name: "Tim", gender: "male", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Ask him about"
    end

    test "English prompt uses 'her' when other is female" do
      user = user_fixture(display_name: "Tim", gender: "male", language: "en")
      other = user_fixture(display_name: "Aisha", gender: "female", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Ask her about"
    end

    test "prompt includes gender and height" do
      user = user_fixture(display_name: "Alice", gender: "female", height: 168, language: "en")
      other = user_fixture(display_name: "Bob", gender: "male", height: 192, language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Gender: female"
      assert prompt =~ "Gender: male"
      assert prompt =~ "Height: 168 cm"
      assert prompt =~ "Height: 192 cm"
    end

    test "prompt includes search preferences" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Looking for age:"
      assert prompt =~ "Looking for height:"
      assert prompt =~ "Search radius:"
    end

    test "prompt includes distance" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Distance: ~0 km"
    end

    test "German prompt uses German labels throughout" do
      user = user_fixture(display_name: "Anna", gender: "female", height: 168, language: "de")
      other = user_fixture(display_name: "Ben", gender: "male", height: 185, language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      # Section headers introduce both people by name and role
      assert prompt =~ "Anna (dein User)"
      assert prompt =~ "Ben (das Gegenüber)"

      assert prompt =~ "Geschlecht: weiblich"
      assert prompt =~ "Geschlecht: männlich"
      assert prompt =~ "Größe: 168 cm"
      assert prompt =~ "Größe: 185 cm"
      assert prompt =~ "Sucht Alter:"
      assert prompt =~ "Sucht Größe:"
      assert prompt =~ "Suchradius:"
      assert prompt =~ "Entfernung:"
      assert prompt =~ "Gib NUR gültiges JSON"

      # Should NOT contain English labels
      refute prompt =~ "Gender:"
      refute prompt =~ "Height:"
      refute prompt =~ "Looking for"
      refute prompt =~ "Search radius:"
      refute prompt =~ "Distance:"
      refute prompt =~ "Return ONLY valid JSON"
    end

    test "English prompt does not contain German labels" do
      user = user_fixture(display_name: "Alice", gender: "female", height: 168, language: "en")
      other = user_fixture(display_name: "Bob", gender: "male", height: 185, language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      # Section headers introduce both people by name and role
      assert prompt =~ "Alice (your user)"
      assert prompt =~ "Bob (the other person)"

      assert prompt =~ "Gender: female"
      assert prompt =~ "Height: 168 cm"
      assert prompt =~ "Looking for age:"
      assert prompt =~ "Search radius:"
      assert prompt =~ "Return ONLY valid JSON"
    end

    test "prompt includes no-sex rule in German" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "KEIN Thema Sex"
    end

    test "prompt includes no-sex rule in English" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "NEVER mention sex"
    end

    test "wildcard context adds German hint to prompt" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      context = %{context | is_wildcard: true}
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Wildcard-Vorschlag"
      assert prompt =~ "Erfinde keine Gemeinsamkeiten"
    end

    test "wildcard context adds English hint to prompt" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      context = %{context | is_wildcard: true}
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "wildcard suggestion"
      assert prompt =~ "Don't invent similarities"
    end

    test "non-wildcard context does not include wildcard hint" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      refute prompt =~ "wildcard"
    end
  end

  describe "build_prompt flag system and moodboard explanation" do
    test "German prompt includes moodboard explanation" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Moodboard"
      assert prompt =~ "Geschichten"
    end

    test "English prompt includes moodboard explanation" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Moodboard"
      assert prompt =~ "stories"
    end

    test "German prompt includes flag system explanation" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Weiße Flaggen"
      assert prompt =~ "Grüne Flaggen"
      assert prompt =~ "wichtig"
      assert prompt =~ "flexibel"
      # Rote Flaggen should not be mentioned (they are never shown)
      refute prompt =~ "Rote Flaggen"
    end

    test "English prompt includes flag system explanation" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "White flags"
      assert prompt =~ "Green flags"
      assert prompt =~ "hard"
      assert prompt =~ "soft"
      # Red flags should not be mentioned (they are never shown)
      refute prompt =~ "Red flags"
    end

    test "German prompt includes dating platform context" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "ANIMINA"
      assert prompt =~ "Online-Dating-Plattform"
      assert prompt =~ "erste Nachricht"
    end

    test "English prompt includes dating platform context" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "ANIMINA"
      assert prompt =~ "online dating platform"
      assert prompt =~ "first message"
    end

    test "German prompt does not contain private flag names or private flag section" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      refute prompt =~ "Privat — NICHT beim Namen"
      refute prompt =~ "NICHT beim Namen nennen!"
    end

    test "English prompt does not contain private flag names or private flag section" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      refute prompt =~ "Private — NEVER mention by name"
      refute prompt =~ "NEVER by name"
    end

    test "German prompt includes rule about known shared traits being facts" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Bekannte Gemeinsamkeiten"
      assert prompt =~ "FAKTEN"
    end

    test "English prompt includes rule about known shared traits being facts" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Known shared traits"
      assert prompt =~ "FACTS"
    end

    test "German prompt includes rule about not inventing traits" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Erfinde keine Aktivitäten"
    end

    test "English prompt includes rule about not inventing traits" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Do not invent activities"
    end

    test "German prompt includes rule about green flags meaning" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Grüne Flaggen zeigen"
      assert prompt =~ "beim PARTNER sucht"
    end

    test "English prompt includes rule about green flags meaning" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])
      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Green flags show"
      assert prompt =~ "SEEKS in a partner"
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
  end

  describe "build_prompt private overlap hints" do
    test "German prompt renders structured hints for private overlaps" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])

      # Inject a fake private overlap to verify hint rendering
      context =
        put_in(context, [:overlap, :shared_traits_private], ["Hobbies: Segeln"])

      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Gesprächshinweise (basierend auf Profilanalyse):"
      assert prompt =~ "Dein User mag:"
      assert prompt =~ "Schlage vor zu fragen"
    end

    test "English prompt renders structured hints for private overlaps" do
      user = user_fixture(display_name: "Alice", language: "en")
      other = user_fixture(display_name: "Bob", language: "en")

      context = Wingman.gather_context(user, other, [])

      context =
        put_in(context, [:overlap, :shared_traits_private], ["Hobbies: Sailing"])

      prompt = Wingman.build_prompt(context, "en")

      assert prompt =~ "Conversation hints (based on profile analysis):"
      assert prompt =~ "Your user likes:"
      assert prompt =~ "Suggest asking"
    end

    test "sex-related categories are excluded from private overlap hints" do
      user = user_fixture(display_name: "Anna", language: "de")
      other = user_fixture(display_name: "Ben", language: "de")

      context = Wingman.gather_context(user, other, [])

      context =
        put_in(context, [:overlap, :shared_traits_private], [
          "Hobbies: Segeln",
          "Sexual Preferences: BDSM",
          "Sexual Practices: Tantra"
        ])

      prompt = Wingman.build_prompt(context, "de")

      assert prompt =~ "Segeln"
      refute prompt =~ "BDSM"
      refute prompt =~ "Tantra"
      refute prompt =~ "Sexual Preferences"
      refute prompt =~ "Sexual Practices"
    end
  end
end
