defmodule Animina.Discovery.SpotlightTest do
  use Animina.DataCase, async: true

  import Animina.AccountsFixtures

  alias Animina.Accounts
  alias Animina.Accounts.Scope
  alias Animina.Discovery
  alias Animina.Discovery.Spotlight
  alias Animina.Messaging

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

    candidates =
      for i <- 1..10 do
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
      assert length(users) > 0
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

      if length(users) > 0 do
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
