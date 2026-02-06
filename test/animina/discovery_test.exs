defmodule Animina.DiscoveryTest do
  use Animina.DataCase

  alias Animina.Discovery
  alias Animina.Discovery.Schemas.{Dismissal, SuggestionView}
  alias Animina.Repo

  import Animina.AccountsFixtures

  describe "dismissals" do
    test "dismiss_user/2 creates a dismissal record" do
      viewer = user_fixture()
      target = user_fixture()

      assert {:ok, %Dismissal{}} = Discovery.dismiss_user(viewer, target)
      assert Discovery.dismissed?(viewer.id, target.id)
    end

    test "dismiss_user/2 is idempotent" do
      viewer = user_fixture()
      target = user_fixture()

      assert {:ok, _} = Discovery.dismiss_user(viewer, target)
      assert {:ok, _} = Discovery.dismiss_user(viewer, target)

      assert Discovery.dismissal_count(viewer.id) == 1
    end

    test "dismissed?/2 returns false for non-dismissed users" do
      viewer = user_fixture()
      target = user_fixture()

      refute Discovery.dismissed?(viewer.id, target.id)
    end

    test "dismissal_count/1 returns the correct count" do
      viewer = user_fixture()
      target1 = user_fixture()
      target2 = user_fixture()

      assert Discovery.dismissal_count(viewer.id) == 0

      Discovery.dismiss_user(viewer, target1)
      assert Discovery.dismissal_count(viewer.id) == 1

      Discovery.dismiss_user(viewer, target2)
      assert Discovery.dismissal_count(viewer.id) == 2
    end
  end

  describe "suggestion_views" do
    test "recently_shown?/3 returns false for new users" do
      viewer = user_fixture()
      target = user_fixture()

      refute Discovery.recently_shown?(viewer.id, target.id, "combined")
    end

    test "recently_shown?/3 returns true after recording a view" do
      viewer = user_fixture() |> activate_user()
      target = user_fixture() |> activate_user()

      # Create a suggestion manually
      suggestion = %{
        user: target,
        score: 100,
        overlap: %{},
        list_type: "combined",
        has_soft_red: false,
        soft_red_count: 0,
        green_count: 0,
        white_white_count: 0
      }

      Discovery.record_suggestion_views(viewer, [suggestion])

      assert Discovery.recently_shown?(viewer.id, target.id, "combined")
    end

    test "suggestion_view_count/1 returns unique user count" do
      viewer = user_fixture() |> activate_user()
      target = user_fixture() |> activate_user()

      assert Discovery.suggestion_view_count(viewer.id) == 0

      suggestion = %{
        user: target,
        score: 100,
        overlap: %{},
        list_type: "combined",
        has_soft_red: false,
        soft_red_count: 0,
        green_count: 0,
        white_white_count: 0
      }

      Discovery.record_suggestion_views(viewer, [suggestion])
      assert Discovery.suggestion_view_count(viewer.id) == 1

      # Recording for different list type should still count as same user
      suggestion_safe = %{suggestion | list_type: "safe"}
      Discovery.record_suggestion_views(viewer, [suggestion_safe])
      assert Discovery.suggestion_view_count(viewer.id) == 1
    end
  end

  describe "cleanup_old_suggestion_views/0" do
    test "deletes old records" do
      viewer = user_fixture()
      target = user_fixture()

      # Insert an old suggestion view (60 days ago)
      old_date = DateTime.utc_now() |> DateTime.add(-60, :day) |> DateTime.truncate(:second)

      %SuggestionView{}
      |> SuggestionView.changeset(%{
        viewer_id: viewer.id,
        suggested_id: target.id,
        list_type: "combined",
        shown_at: old_date
      })
      |> Repo.insert!()

      assert {:ok, 1} = Discovery.cleanup_old_suggestion_views()
    end

    test "keeps recent records" do
      viewer = user_fixture()
      target = user_fixture()

      # Insert a recent suggestion view
      recent_date = DateTime.utc_now() |> DateTime.truncate(:second)

      %SuggestionView{}
      |> SuggestionView.changeset(%{
        viewer_id: viewer.id,
        suggested_id: target.id,
        list_type: "combined",
        shown_at: recent_date
      })
      |> Repo.insert!()

      assert {:ok, 0} = Discovery.cleanup_old_suggestion_views()
    end
  end

  describe "profile visits" do
    test "record_profile_visit/2 creates a visit record" do
      visitor = user_fixture()
      visited = user_fixture()

      assert {:ok, _} = Discovery.record_profile_visit(visitor.id, visited.id)
      assert Discovery.has_visited_profile?(visitor.id, visited.id)
    end

    test "record_profile_visit/2 is idempotent" do
      visitor = user_fixture()
      visited = user_fixture()

      assert {:ok, _} = Discovery.record_profile_visit(visitor.id, visited.id)
      assert {:ok, _} = Discovery.record_profile_visit(visitor.id, visited.id)

      # Should still only have one visit
      result = Discovery.visited_profile_ids(visitor.id, [visited.id])
      assert MapSet.size(result) == 1
    end

    test "has_visited_profile?/2 returns false for unvisited profiles" do
      visitor = user_fixture()
      visited = user_fixture()

      refute Discovery.has_visited_profile?(visitor.id, visited.id)
    end

    test "visited_profile_ids/2 returns correct set of visited users" do
      visitor = user_fixture()
      visited1 = user_fixture()
      visited2 = user_fixture()
      not_visited = user_fixture()

      Discovery.record_profile_visit(visitor.id, visited1.id)
      Discovery.record_profile_visit(visitor.id, visited2.id)

      result =
        Discovery.visited_profile_ids(visitor.id, [visited1.id, visited2.id, not_visited.id])

      assert MapSet.member?(result, visited1.id)
      assert MapSet.member?(result, visited2.id)
      refute MapSet.member?(result, not_visited.id)
    end

    test "visited_profile_ids/2 returns empty set for no visits" do
      visitor = user_fixture()
      other = user_fixture()

      result = Discovery.visited_profile_ids(visitor.id, [other.id])
      assert MapSet.size(result) == 0
    end
  end

  describe "settings access" do
    test "suggestions_per_list/0 returns a positive integer" do
      assert is_integer(Discovery.suggestions_per_list())
      assert Discovery.suggestions_per_list() > 0
    end

    test "cooldown_days/0 returns a positive integer" do
      assert is_integer(Discovery.cooldown_days())
      assert Discovery.cooldown_days() > 0
    end
  end

  # Helper to activate a user (change state from waitlisted to normal)
  defp activate_user(user) do
    user
    |> Ecto.Changeset.change(state: "normal")
    |> Repo.update!()
  end
end
