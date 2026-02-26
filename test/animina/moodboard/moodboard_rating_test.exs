defmodule Animina.Moodboard.MoodboardRatingTest do
  use Animina.DataCase, async: true

  alias Animina.Moodboard
  alias Animina.Moodboard.MoodboardRating
  alias Animina.Repo

  import Animina.MoodboardFixtures

  describe "toggle_rating/3" do
    test "creates a new rating" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      assert {:ok, :created, rating} = Moodboard.toggle_rating(voter.id, item.id, 1)
      assert rating.user_id == voter.id
      assert rating.moodboard_item_id == item.id
      assert rating.value == 1
    end

    test "toggles off when same value is clicked" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item.id, 1)
      assert {:ok, :removed} = Moodboard.toggle_rating(voter.id, item.id, 1)

      assert Moodboard.get_rating(voter.id, item.id) == nil
    end

    test "switches to different value" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item.id, 1)
      assert {:ok, :switched, rating} = Moodboard.toggle_rating(voter.id, item.id, 2)
      assert rating.value == 2
    end

    test "rejects owner rating own item" do
      owner = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      assert {:error, :own_item} = Moodboard.toggle_rating(owner.id, item.id, 1)
    end

    test "rejects invalid item ID" do
      voter = bare_user_fixture()

      assert {:error, :item_not_found} =
               Moodboard.toggle_rating(voter.id, Ecto.UUID.generate(), 1)
    end

    test "rejects invalid value" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      assert {:error, %Ecto.Changeset{}} = Moodboard.toggle_rating(voter.id, item.id, 3)
    end

    test "supports all valid values" do
      owner = bare_user_fixture()

      for value <- [-1, 1, 2] do
        voter = bare_user_fixture()
        item = moodboard_item_fixture(%{user_id: owner.id})
        assert {:ok, :created, rating} = Moodboard.toggle_rating(voter.id, item.id, value)
        assert rating.value == value
      end
    end
  end

  describe "get_rating/2" do
    test "returns rating when it exists" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, created} = Moodboard.toggle_rating(voter.id, item.id, 1)
      found = Moodboard.get_rating(voter.id, item.id)

      assert found.id == created.id
      assert found.value == 1
    end

    test "returns nil when no rating exists" do
      voter = bare_user_fixture()
      assert Moodboard.get_rating(voter.id, Ecto.UUID.generate()) == nil
    end
  end

  describe "user_ratings_for_items/2" do
    test "returns map of item_id => value" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item1 = moodboard_item_fixture(%{user_id: owner.id})
      item2 = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item1.id, 1)
      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item2.id, -1)

      ratings = Moodboard.user_ratings_for_items(voter.id, [item1.id, item2.id])

      assert ratings == %{item1.id => 1, item2.id => -1}
    end

    test "returns empty map when no ratings" do
      voter = bare_user_fixture()
      assert Moodboard.user_ratings_for_items(voter.id, [Ecto.UUID.generate()]) == %{}
    end

    test "only returns ratings for specified items" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item1 = moodboard_item_fixture(%{user_id: owner.id})
      item2 = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item1.id, 1)
      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item2.id, 2)

      # Only ask for item1
      ratings = Moodboard.user_ratings_for_items(voter.id, [item1.id])
      assert ratings == %{item1.id => 1}
    end

    test "returns empty map for empty item list" do
      voter = bare_user_fixture()
      assert Moodboard.user_ratings_for_items(voter.id, []) == %{}
    end
  end

  describe "aggregate_ratings_for_items/1" do
    test "returns grouped counts per item" do
      owner = bare_user_fixture()
      voter1 = bare_user_fixture()
      voter2 = bare_user_fixture()
      voter3 = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter1.id, item.id, 1)
      {:ok, :created, _} = Moodboard.toggle_rating(voter2.id, item.id, 1)
      {:ok, :created, _} = Moodboard.toggle_rating(voter3.id, item.id, 2)

      aggregates = Moodboard.aggregate_ratings_for_items([item.id])
      assert aggregates[item.id] == %{1 => 2, 2 => 1}
    end

    test "returns empty map for unrated items" do
      owner = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      assert Moodboard.aggregate_ratings_for_items([item.id]) == %{}
    end

    test "returns empty map for empty item list" do
      assert Moodboard.aggregate_ratings_for_items([]) == %{}
    end

    test "handles multiple items with mixed ratings" do
      owner = bare_user_fixture()
      voter1 = bare_user_fixture()
      voter2 = bare_user_fixture()
      item1 = moodboard_item_fixture(%{user_id: owner.id})
      item2 = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter1.id, item1.id, -1)
      {:ok, :created, _} = Moodboard.toggle_rating(voter2.id, item1.id, 1)
      {:ok, :created, _} = Moodboard.toggle_rating(voter1.id, item2.id, 2)

      aggregates = Moodboard.aggregate_ratings_for_items([item1.id, item2.id])
      assert aggregates[item1.id] == %{-1 => 1, 1 => 1}
      assert aggregates[item2.id] == %{2 => 1}
    end
  end

  describe "cascade deletes" do
    test "ratings are deleted when moodboard item is hard-deleted" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item.id, 1)
      assert Moodboard.get_rating(voter.id, item.id) != nil

      Moodboard.hard_delete_item(item)
      assert Repo.all(MoodboardRating) == []
    end

    test "ratings are deleted when user is deleted" do
      owner = bare_user_fixture()
      voter = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: owner.id})

      {:ok, :created, _} = Moodboard.toggle_rating(voter.id, item.id, 1)

      Repo.delete(voter)
      assert Repo.all(MoodboardRating) == []
    end
  end
end
