defmodule Animina.Discovery.SpotlightTest do
  use Animina.DataCase, async: true

  import Animina.AccountsFixtures

  alias Animina.Accounts
  alias Animina.Accounts.Scope
  alias Animina.Discovery
  alias Animina.Discovery.Schemas.SpotlightEntry
  alias Animina.Discovery.Spotlight
  alias Animina.Messaging

  # The Spotlight module uses Berlin dates internally, so tests must match
  defp berlin_today do
    DateTime.utc_now()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> DateTime.to_date()
  end

  # Helper to activate a user (change state from waitlisted to normal)
  defp activate_user(user) do
    user
    |> Ecto.Changeset.change(state: "normal")
    |> Repo.update!()
  end

  defp preload_locations(user) do
    Repo.preload(user, :locations)
  end

  defp setup_viewer_and_candidates(_context) do
    viewer =
      user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
      |> activate_user()
      |> preload_locations()

    # Need 18+ candidates: 8 per day × 2 days + headroom for exclusions
    candidates =
      for i <- 1..18 do
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          display_name: "Candidate #{i}"
        })
        |> activate_user()
        |> preload_locations()
      end

    %{viewer: viewer, candidates: candidates}
  end

  describe "get_or_seed_daily/1" do
    setup :setup_viewer_and_candidates

    test "seeds spotlight entries on first call", %{viewer: viewer} do
      {users, wildcard_ids} = Spotlight.get_or_seed_daily(viewer)

      # Should return some users (up to 6 pool + 2 wildcard)
      assert users != []
      assert length(users) <= 8

      # wildcard_ids should be a MapSet
      assert %MapSet{} = wildcard_ids
    end

    test "returns same set on second call", %{viewer: viewer} do
      {users1, _} = Spotlight.get_or_seed_daily(viewer)
      {users2, _} = Spotlight.get_or_seed_daily(viewer)

      ids1 = Enum.map(users1, & &1.id) |> Enum.sort()
      ids2 = Enum.map(users2, & &1.id) |> Enum.sort()

      assert ids1 == ids2
    end

    test "excludes dismissed users", %{viewer: viewer, candidates: candidates} do
      # Dismiss first 3 candidates
      for c <- Enum.take(candidates, 3) do
        Discovery.dismiss_user(viewer, c)
      end

      {users, _} = Spotlight.get_or_seed_daily(viewer)
      user_ids = MapSet.new(Enum.map(users, & &1.id))
      dismissed_ids = Enum.take(candidates, 3) |> Enum.map(& &1.id) |> MapSet.new()

      assert MapSet.disjoint?(user_ids, dismissed_ids)
    end

    test "excludes conversation partners", %{viewer: viewer, candidates: candidates} do
      # Create a conversation with first candidate
      partner = hd(candidates)
      {:ok, _conv} = Messaging.get_or_create_conversation(viewer.id, partner.id)

      {users, _} = Spotlight.get_or_seed_daily(viewer)
      user_ids = Enum.map(users, & &1.id)

      refute partner.id in user_ids
    end
  end

  describe "has_moodboard_access?/3" do
    setup :setup_viewer_and_candidates

    test "owner always has access", %{viewer: viewer} do
      scope = Scope.for_user(viewer)
      assert Spotlight.has_moodboard_access?(viewer, viewer, scope)
    end

    test "admin has access to any profile", %{candidates: candidates} do
      admin = admin_fixture()
      admin_scope = admin_scope_fixture(admin)
      profile_user = hd(candidates)

      assert Spotlight.has_moodboard_access?(admin, profile_user, admin_scope)
    end

    test "moderator has access to any profile", %{candidates: candidates} do
      moderator = moderator_fixture()
      mod_scope = moderator_scope_fixture(moderator)
      profile_user = hd(candidates)

      assert Spotlight.has_moodboard_access?(moderator, profile_user, mod_scope)
    end

    test "user with active conversation has access", %{viewer: viewer, candidates: candidates} do
      partner = hd(candidates)
      {:ok, _conv} = Messaging.get_or_create_conversation(viewer.id, partner.id)

      scope = Scope.for_user(viewer)
      assert Spotlight.has_moodboard_access?(viewer, partner, scope)
    end

    test "user in spotlight has bidirectional access", %{viewer: viewer} do
      # Seed spotlight for viewer (which will include some candidates)
      {users, _} = Spotlight.get_or_seed_daily(viewer)

      if users != [] do
        spotlight_user = hd(users)
        viewer_scope = Scope.for_user(viewer)
        candidate_scope = Scope.for_user(spotlight_user)

        # Viewer can see spotlight user's profile
        assert Spotlight.has_moodboard_access?(viewer, spotlight_user, viewer_scope)

        # Spotlight user can see viewer's profile (bidirectional)
        assert Spotlight.has_moodboard_access?(spotlight_user, viewer, candidate_scope)
      end
    end

    test "user without spotlight or conversation has no access", %{} do
      user_a =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          display_name: "Alice"
        })
        |> activate_user()

      user_b =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          display_name: "Britta"
        })
        |> activate_user()

      scope = Scope.for_user(user_a)
      refute Spotlight.has_moodboard_access?(user_a, user_b, scope)
    end

    test "nil viewer has no access", %{candidates: candidates} do
      profile_user = hd(candidates)
      refute Spotlight.has_moodboard_access?(nil, profile_user, nil)
    end
  end

  describe "preview_candidates/1" do
    setup :setup_viewer_and_candidates

    test "returns up to 4 candidates", %{viewer: viewer} do
      # Seed today's spotlight first
      Spotlight.get_or_seed_daily(viewer)

      previews = Spotlight.preview_candidates(viewer)
      assert length(previews) <= 4
    end

    test "excludes today's spotlight entries", %{viewer: viewer} do
      {today_users, _} = Spotlight.get_or_seed_daily(viewer)
      today_ids = Enum.map(today_users, & &1.id) |> MapSet.new()

      previews = Spotlight.preview_candidates(viewer)
      preview_ids = Enum.map(previews, & &1.id) |> MapSet.new()

      assert MapSet.disjoint?(today_ids, preview_ids)
    end

    test "excludes dismissed users", %{viewer: viewer, candidates: candidates} do
      # Dismiss some candidates
      for c <- Enum.take(candidates, 5) do
        Discovery.dismiss_user(viewer, c)
      end

      Spotlight.get_or_seed_daily(viewer)
      previews = Spotlight.preview_candidates(viewer)
      preview_ids = Enum.map(previews, & &1.id) |> MapSet.new()
      dismissed_ids = Enum.take(candidates, 5) |> Enum.map(& &1.id) |> MapSet.new()

      assert MapSet.disjoint?(preview_ids, dismissed_ids)
    end

    test "excludes conversation partners", %{viewer: viewer, candidates: candidates} do
      partner = hd(candidates)
      {:ok, _conv} = Messaging.get_or_create_conversation(viewer.id, partner.id)

      Spotlight.get_or_seed_daily(viewer)
      previews = Spotlight.preview_candidates(viewer)
      preview_ids = Enum.map(previews, & &1.id)

      refute partner.id in preview_ids
    end
  end

  describe "seed_tomorrow/2 (via get_or_seed_daily)" do
    setup :setup_viewer_and_candidates

    test "creates entries for tomorrow after seeding today", %{viewer: viewer} do
      Spotlight.get_or_seed_daily(viewer)

      tomorrow = Date.add(berlin_today(), 1)

      tomorrow_entries =
        SpotlightEntry
        |> where([e], e.user_id == ^viewer.id and e.shown_on == ^tomorrow)
        |> Repo.all()

      assert tomorrow_entries != []
      assert length(tomorrow_entries) <= 8
    end

    test "tomorrow entries don't overlap with today", %{viewer: viewer} do
      {today_users, _} = Spotlight.get_or_seed_daily(viewer)
      today_ids = Enum.map(today_users, & &1.id) |> MapSet.new()

      tomorrow = Date.add(berlin_today(), 1)

      tomorrow_ids =
        SpotlightEntry
        |> where([e], e.user_id == ^viewer.id and e.shown_on == ^tomorrow)
        |> select([e], e.shown_user_id)
        |> Repo.all()
        |> MapSet.new()

      assert MapSet.disjoint?(today_ids, tomorrow_ids)
    end

    test "seeding is idempotent — second call doesn't duplicate tomorrow entries", %{
      viewer: viewer
    } do
      Spotlight.get_or_seed_daily(viewer)
      Spotlight.get_or_seed_daily(viewer)

      tomorrow = Date.add(berlin_today(), 1)

      tomorrow_entries =
        SpotlightEntry
        |> where([e], e.user_id == ^viewer.id and e.shown_on == ^tomorrow)
        |> Repo.all()

      assert length(tomorrow_entries) <= 8
    end
  end

  describe "preview_candidates/1 returns from tomorrow's entries" do
    setup :setup_viewer_and_candidates

    test "returns users from tomorrow's pre-seeded entries", %{viewer: viewer} do
      Spotlight.get_or_seed_daily(viewer)

      tomorrow = Date.add(berlin_today(), 1)

      tomorrow_user_ids =
        SpotlightEntry
        |> where([e], e.user_id == ^viewer.id and e.shown_on == ^tomorrow)
        |> select([e], e.shown_user_id)
        |> Repo.all()
        |> MapSet.new()

      previews = Spotlight.preview_candidates(viewer)
      preview_ids = Enum.map(previews, & &1.id) |> MapSet.new()

      # All preview candidates should come from tomorrow's entries
      assert MapSet.subset?(preview_ids, tomorrow_user_ids)
    end

    test "returns max 4 even though 8 are pre-seeded", %{viewer: viewer} do
      Spotlight.get_or_seed_daily(viewer)
      previews = Spotlight.preview_candidates(viewer)
      assert length(previews) <= 4
    end

    test "returns stable results across calls", %{viewer: viewer} do
      Spotlight.get_or_seed_daily(viewer)

      previews1 = Spotlight.preview_candidates(viewer)
      previews2 = Spotlight.preview_candidates(viewer)

      ids1 = Enum.map(previews1, & &1.id) |> Enum.sort()
      ids2 = Enum.map(previews2, & &1.id) |> Enum.sort()

      assert ids1 == ids2
    end
  end

  describe "get_or_seed_daily/1 validates pre-seeded entries" do
    setup :setup_viewer_and_candidates

    test "replaces invalid (waitlisted) pre-seeded user on next day", %{
      viewer: viewer,
      candidates: candidates
    } do
      # Seed today (which also seeds tomorrow)
      Spotlight.get_or_seed_daily(viewer)

      tomorrow = Date.add(berlin_today(), 1)

      tomorrow_entries =
        SpotlightEntry
        |> where([e], e.user_id == ^viewer.id and e.shown_on == ^tomorrow)
        |> Repo.all()

      # Pick one of tomorrow's shown_user_ids and waitlist them
      if tomorrow_entries != [] do
        entry = hd(tomorrow_entries)
        target = Enum.find(candidates, &(&1.id == entry.shown_user_id))

        if target do
          target
          |> Ecto.Changeset.change(state: "waitlisted")
          |> Repo.update!()

          # Now load those entries as "today" by rewriting shown_on
          # (simulates the next day arriving)
          Repo.update_all(
            from(e in SpotlightEntry,
              where: e.user_id == ^viewer.id and e.shown_on == ^tomorrow
            ),
            set: [shown_on: berlin_today()]
          )

          # Delete the old today entries
          today = berlin_today()

          Repo.delete_all(
            from(e in SpotlightEntry,
              where:
                e.user_id == ^viewer.id and e.shown_on == ^today and
                  e.id not in ^Enum.map(tomorrow_entries, & &1.id)
            )
          )

          # Now calling get_or_seed_daily should validate and replace the waitlisted user
          {users, _} = Spotlight.get_or_seed_daily(viewer)
          user_ids = Enum.map(users, & &1.id)

          refute target.id in user_ids
        end
      end
    end
  end

  describe "build_preview_hints/1" do
    setup :setup_viewer_and_candidates

    test "returns metadata for preview candidates", %{viewer: viewer} do
      Spotlight.get_or_seed_daily(viewer)
      previews = Spotlight.preview_candidates(viewer)

      hints = Spotlight.build_preview_hints(previews)

      for hint <- hints do
        assert Map.has_key?(hint, :id)
        assert Map.has_key?(hint, :pixelated_avatar_url)
        assert Map.has_key?(hint, :age)
        assert Map.has_key?(hint, :gender_symbol)
        assert Map.has_key?(hint, :city_name)
        assert Map.has_key?(hint, :obfuscated_name)

        # Obfuscated name should be first char + "..."
        assert String.ends_with?(hint.obfuscated_name, "...")
        assert String.length(hint.obfuscated_name) >= 4
      end
    end

    test "returns empty list for empty input", %{} do
      assert Spotlight.build_preview_hints([]) == []
    end
  end

  describe "countdown helpers" do
    test "seconds_until_midnight returns non-negative integer" do
      seconds = Spotlight.seconds_until_midnight()
      assert is_integer(seconds)
      assert seconds >= 0
    end

    test "format_countdown formats hours and minutes" do
      assert Spotlight.format_countdown(7200) == "2h 0m"
      assert Spotlight.format_countdown(3661) == "1h 1m"
      assert Spotlight.format_countdown(300) == "5m"
      assert Spotlight.format_countdown(30) == "< 1m"
    end
  end

  # --- Helper to create admin/moderator scopes ---

  defp admin_scope_fixture(admin) do
    roles = Accounts.get_user_roles(admin)
    Scope.for_user(admin, roles, "admin")
  end

  defp moderator_scope_fixture(moderator) do
    roles = Accounts.get_user_roles(moderator)
    Scope.for_user(moderator, roles, "moderator")
  end
end
