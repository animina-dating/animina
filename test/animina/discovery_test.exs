defmodule Animina.DiscoveryTest do
  use Animina.DataCase, async: true

  alias Animina.Discovery

  import Animina.AccountsFixtures

  describe "dismissals" do
    test "dismiss_user/2 creates a dismissal record" do
      viewer = user_fixture()
      target = user_fixture()

      assert {:ok, _} = Discovery.dismiss_user(viewer, target)
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
end
