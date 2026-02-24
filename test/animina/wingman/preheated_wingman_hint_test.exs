defmodule Animina.Wingman.PreheatedWingmanHintTest do
  use Animina.DataCase, async: true

  alias Animina.Wingman
  alias Animina.Wingman.PreheatedWingmanHint

  import Animina.AccountsFixtures

  describe "PreheatedWingmanHint changeset" do
    test "valid changeset with required fields" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      changeset =
        PreheatedWingmanHint.changeset(%PreheatedWingmanHint{}, %{
          user_id: user.id,
          other_user_id: other.id,
          shown_on: ~D[2026-02-24]
        })

      assert changeset.valid?
    end

    test "invalid changeset without required fields" do
      changeset = PreheatedWingmanHint.changeset(%PreheatedWingmanHint{}, %{})
      refute changeset.valid?
      assert %{user_id: _, other_user_id: _, shown_on: _} = errors_on(changeset)
    end

    test "changeset with suggestions" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      changeset =
        PreheatedWingmanHint.changeset(%PreheatedWingmanHint{}, %{
          user_id: user.id,
          other_user_id: other.id,
          shown_on: ~D[2026-02-24],
          suggestions: [%{"text" => "Ask about hiking!", "hook" => "shared interest"}]
        })

      assert changeset.valid?
    end
  end

  describe "save_preheated_hint/6" do
    test "inserts a new hint" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")
      today = Date.utc_today()
      suggestions = [%{"text" => "Try this!", "hook" => "reason"}]

      assert {:ok, hint} =
               Wingman.save_preheated_hint(user.id, other.id, today, suggestions, "abc123", nil)

      assert hint.user_id == user.id
      assert hint.other_user_id == other.id
      assert hint.shown_on == today
      assert hint.suggestions == suggestions
      assert hint.context_hash == "abc123"
    end

    test "upserts on conflict" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")
      today = Date.utc_today()

      suggestions1 = [%{"text" => "First", "hook" => "r1"}]
      suggestions2 = [%{"text" => "Updated", "hook" => "r2"}]

      {:ok, _} = Wingman.save_preheated_hint(user.id, other.id, today, suggestions1, "hash1", nil)
      {:ok, hint} = Wingman.save_preheated_hint(user.id, other.id, today, suggestions2, "hash2", nil)

      assert hint.suggestions == suggestions2
      assert hint.context_hash == "hash2"
    end
  end

  describe "get_preheated_hint/2" do
    test "returns hint for today" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      now_berlin =
        DateTime.utc_now()
        |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

      today = DateTime.to_date(now_berlin)
      suggestions = [%{"text" => "Tip", "hook" => "hook"}]

      Wingman.save_preheated_hint(user.id, other.id, today, suggestions, "hash", nil)

      hint = Wingman.get_preheated_hint(user.id, other.id)
      assert hint != nil
      assert hint.suggestions == suggestions
    end

    test "returns nil for non-existent pair" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      assert Wingman.get_preheated_hint(user.id, other.id) == nil
    end

    test "returns nil for hint without suggestions" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      now_berlin =
        DateTime.utc_now()
        |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

      today = DateTime.to_date(now_berlin)

      # Insert a hint without suggestions (just the placeholder row)
      Wingman.save_preheated_hint(user.id, other.id, today, nil, "hash", nil)

      assert Wingman.get_preheated_hint(user.id, other.id) == nil
    end
  end

  describe "invalidate_preheated_hints/1" do
    test "deletes hints where user is viewer" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      now_berlin =
        DateTime.utc_now()
        |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

      today = DateTime.to_date(now_berlin)
      suggestions = [%{"text" => "Tip", "hook" => "hook"}]

      Wingman.save_preheated_hint(user.id, other.id, today, suggestions, "hash", nil)
      assert Wingman.get_preheated_hint(user.id, other.id) != nil

      Wingman.invalidate_preheated_hints(user.id)
      assert Wingman.get_preheated_hint(user.id, other.id) == nil
    end

    test "deletes hints where user is the shown profile" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")

      now_berlin =
        DateTime.utc_now()
        |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

      today = DateTime.to_date(now_berlin)
      suggestions = [%{"text" => "Tip", "hook" => "hook"}]

      # user is viewer, other is shown profile
      Wingman.save_preheated_hint(user.id, other.id, today, suggestions, "hash", nil)
      assert Wingman.get_preheated_hint(user.id, other.id) != nil

      # Invalidate by other_user_id (the shown profile edited their profile)
      Wingman.invalidate_preheated_hints(other.id)
      assert Wingman.get_preheated_hint(user.id, other.id) == nil
    end

    test "does not delete hints for other users" do
      user1 = user_fixture(language: "en")
      user2 = user_fixture(language: "en")
      user3 = user_fixture(language: "en")

      now_berlin =
        DateTime.utc_now()
        |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

      today = DateTime.to_date(now_berlin)
      suggestions = [%{"text" => "Tip", "hook" => "hook"}]

      Wingman.save_preheated_hint(user1.id, user2.id, today, suggestions, "hash1", nil)
      Wingman.save_preheated_hint(user3.id, user2.id, today, suggestions, "hash2", nil)

      Wingman.invalidate_preheated_hints(user1.id)

      # user1's hint should be gone
      assert Wingman.get_preheated_hint(user1.id, user2.id) == nil
      # user3's hint should remain
      assert Wingman.get_preheated_hint(user3.id, user2.id) != nil
    end
  end

  describe "cleanup_old_preheated_hints/0" do
    test "deletes hints from previous days" do
      user = user_fixture(language: "en")
      other = user_fixture(language: "en")
      yesterday = Date.add(Date.utc_today(), -1)
      suggestions = [%{"text" => "Old tip", "hook" => "old hook"}]

      Wingman.save_preheated_hint(user.id, other.id, yesterday, suggestions, "hash", nil)

      count = Wingman.cleanup_old_preheated_hints()
      assert count >= 1
    end
  end
end
