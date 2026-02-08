defmodule Animina.MoodboardTest do
  use Animina.DataCase

  alias Animina.Accounts.User
  alias Animina.Moodboard
  alias Animina.Moodboard.MoodboardItem
  alias Animina.Moodboard.MoodboardStory
  alias Animina.Repo

  import Animina.AccountsFixtures
  import Animina.MoodboardFixtures

  # Creates a user without going through registration (bypasses pinned item creation)
  defp bare_user_fixture(attrs \\ %{}) do
    attrs = valid_user_attributes(attrs)

    {:ok, user} =
      %User{}
      |> User.registration_changeset(attrs)
      |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
      |> Repo.insert()

    user
  end

  describe "list_moodboard/1" do
    test "returns active moodboard items for a user" do
      user = bare_user_fixture()
      _item1 = photo_moodboard_item_fixture(user, %{position: 1})
      _item2 = story_moodboard_item_fixture(user, "My story", %{position: 2})

      items = Moodboard.list_moodboard(user.id)
      assert length(items) == 2
      assert Enum.all?(items, &(&1.state == "active"))
    end

    test "returns items in position order" do
      user = bare_user_fixture()
      item1 = photo_moodboard_item_fixture(user, %{position: 2})
      item2 = story_moodboard_item_fixture(user, "My story", %{position: 1})

      items = Moodboard.list_moodboard(user.id)
      assert [first, second] = items
      assert first.id == item2.id
      assert second.id == item1.id
    end

    test "excludes hidden items" do
      user = bare_user_fixture()
      _active_item = photo_moodboard_item_fixture(user)
      _hidden_item = hidden_moodboard_item_fixture(user)

      items = Moodboard.list_moodboard(user.id)
      assert length(items) == 1
    end

    test "excludes deleted items" do
      user = bare_user_fixture()
      item = photo_moodboard_item_fixture(user)
      {:ok, _} = Moodboard.delete_item(item)

      items = Moodboard.list_moodboard(user.id)
      assert Enum.empty?(items)
    end
  end

  describe "list_moodboard_with_hidden/1" do
    test "returns both active and hidden items" do
      user = bare_user_fixture()
      _active_item = photo_moodboard_item_fixture(user)
      _hidden_item = hidden_moodboard_item_fixture(user)

      items = Moodboard.list_moodboard_with_hidden(user.id)
      assert length(items) == 2
    end

    test "excludes deleted items" do
      user = bare_user_fixture()
      item = photo_moodboard_item_fixture(user)
      {:ok, _} = Moodboard.delete_item(item)

      items = Moodboard.list_moodboard_with_hidden(user.id)
      assert Enum.empty?(items)
    end
  end

  describe "get_item/1" do
    test "returns the item if found" do
      user = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: user.id})

      found = Moodboard.get_item(item.id)
      assert found.id == item.id
    end

    test "returns nil if not found" do
      assert Moodboard.get_item(Ecto.UUID.generate()) == nil
    end
  end

  describe "update_positions/2" do
    test "updates item positions based on list order" do
      user = bare_user_fixture()
      item1 = moodboard_item_fixture(%{user_id: user.id, position: 1})
      item2 = moodboard_item_fixture(%{user_id: user.id, position: 2})
      item3 = moodboard_item_fixture(%{user_id: user.id, position: 3})

      # Reverse the order
      {:ok, :ok} = Moodboard.update_positions(user.id, [item3.id, item2.id, item1.id])

      # Reload and check
      updated1 = Moodboard.get_item(item1.id)
      updated2 = Moodboard.get_item(item2.id)
      updated3 = Moodboard.get_item(item3.id)

      assert updated3.position == 1
      assert updated2.position == 2
      assert updated1.position == 3
    end

    test "only updates items belonging to the user" do
      user1 = bare_user_fixture()
      user2 = bare_user_fixture()
      item1 = moodboard_item_fixture(%{user_id: user1.id, position: 1})
      item2 = moodboard_item_fixture(%{user_id: user2.id, position: 1})

      # Try to update user2's item as user1
      {:ok, :ok} = Moodboard.update_positions(user1.id, [item2.id, item1.id])

      # user2's item should be unchanged
      updated2 = Moodboard.get_item(item2.id)
      assert updated2.position == 1
    end
  end

  describe "hide_item/2" do
    test "transitions item to hidden state" do
      user = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: user.id})

      assert {:ok, hidden_item} = Moodboard.hide_item(item, "inappropriate_adult")

      assert hidden_item.state == "hidden"
      assert hidden_item.hidden_reason == "inappropriate_adult"
      assert hidden_item.hidden_at
    end

    test "cannot hide a deleted item" do
      user = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: user.id})
      {:ok, deleted} = Moodboard.delete_item(item)

      assert {:error, changeset} = Moodboard.hide_item(deleted, "test")
      assert "cannot transition from deleted to hidden" in errors_on(changeset).state
    end
  end

  describe "unhide_item/1" do
    test "transitions item back to active state" do
      user = bare_user_fixture()
      item = hidden_moodboard_item_fixture(user)

      assert {:ok, active_item} = Moodboard.unhide_item(item)

      assert active_item.state == "active"
      assert active_item.hidden_reason == nil
      assert active_item.hidden_at == nil
    end
  end

  describe "delete_item/1" do
    test "soft-deletes an active item" do
      user = bare_user_fixture()
      item = moodboard_item_fixture(%{user_id: user.id})

      assert {:ok, deleted_item} = Moodboard.delete_item(item)
      assert deleted_item.state == "deleted"
    end

    test "soft-deletes a hidden item" do
      user = bare_user_fixture()
      item = hidden_moodboard_item_fixture(user)

      assert {:ok, deleted_item} = Moodboard.delete_item(item)
      assert deleted_item.state == "deleted"
    end

    test "cannot delete pinned item" do
      user = bare_user_fixture()
      {:ok, pinned} = Moodboard.create_pinned_intro_item(user, "About me")

      assert {:error, :cannot_delete_pinned_item} = Moodboard.delete_item(pinned)

      # Item should still exist
      assert Moodboard.get_pinned_item(user.id) != nil
    end
  end

  describe "count_items/2" do
    test "counts active items by default" do
      user = bare_user_fixture()
      _active1 = moodboard_item_fixture(%{user_id: user.id})
      _active2 = moodboard_item_fixture(%{user_id: user.id})
      _hidden = hidden_moodboard_item_fixture(user)

      assert Moodboard.count_items(user.id) == 2
    end

    test "includes hidden when specified" do
      user = bare_user_fixture()
      _active = moodboard_item_fixture(%{user_id: user.id})
      _hidden = hidden_moodboard_item_fixture(user)

      assert Moodboard.count_items(user.id, true) == 2
    end
  end

  describe "MoodboardItem schema" do
    test "create_changeset validates required fields" do
      changeset = MoodboardItem.create_changeset(%MoodboardItem{}, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors.user_id
      assert "can't be blank" in errors.item_type
    end

    test "create_changeset validates item_type values" do
      changeset =
        MoodboardItem.create_changeset(%MoodboardItem{}, %{
          user_id: Ecto.UUID.generate(),
          item_type: "invalid"
        })

      errors = errors_on(changeset)
      assert "is invalid" in errors.item_type
    end

    test "state_changeset enforces valid transitions" do
      item = %MoodboardItem{state: "active"}
      changeset = MoodboardItem.state_changeset(item, "hidden")
      assert changeset.valid?

      item = %MoodboardItem{state: "deleted"}
      changeset = MoodboardItem.state_changeset(item, "active")
      refute changeset.valid?
    end
  end

  describe "MoodboardStory schema" do
    test "create_changeset validates required fields" do
      changeset = MoodboardStory.create_changeset(%MoodboardStory{}, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors.moodboard_item_id
    end

    test "create_changeset validates content length" do
      long_content = String.duplicate("x", 2001)

      changeset =
        MoodboardStory.create_changeset(%MoodboardStory{}, %{
          moodboard_item_id: Ecto.UUID.generate(),
          content: long_content
        })

      errors = errors_on(changeset)
      assert "should be at most 2000 character(s)" in errors.content
    end
  end

  describe "create_pinned_intro_item/2" do
    test "creates a pinned item at position 1" do
      user = bare_user_fixture()

      assert {:ok, item} = Moodboard.create_pinned_intro_item(user, "Tell us about yourself...")

      assert item.pinned == true
      assert item.position == 1
      assert item.item_type == "combined"
      assert item.moodboard_story.content == "Tell us about yourself..."
    end

    test "shifts existing items to make room" do
      user = bare_user_fixture()
      existing_item = moodboard_item_fixture(%{user_id: user.id, position: 1})

      assert {:ok, _pinned} = Moodboard.create_pinned_intro_item(user, "About me...")

      # Existing item should be shifted to position 2
      refreshed = Moodboard.get_item(existing_item.id)
      assert refreshed.position == 2
    end

    test "only one pinned item per user allowed" do
      user = bare_user_fixture()

      assert {:ok, _first} = Moodboard.create_pinned_intro_item(user, "First intro")

      # Second attempt should fail with :already_exists
      assert {:error, :already_exists} = Moodboard.create_pinned_intro_item(user, "Second intro")
    end
  end

  describe "get_pinned_item/1" do
    test "returns the pinned item for a user" do
      user = bare_user_fixture()
      {:ok, created} = Moodboard.create_pinned_intro_item(user, "My intro")

      found = Moodboard.get_pinned_item(user.id)
      assert found.id == created.id
      assert found.pinned == true
    end

    test "returns nil if no pinned item exists" do
      user = bare_user_fixture()

      assert Moodboard.get_pinned_item(user.id) == nil
    end

    test "pinned items cannot be deleted" do
      user = bare_user_fixture()
      {:ok, item} = Moodboard.create_pinned_intro_item(user, "My intro")

      # Attempting to delete a pinned item should fail
      assert {:error, :cannot_delete_pinned_item} = Moodboard.delete_item(item)

      # Item should still be returned by get_pinned_item
      found = Moodboard.get_pinned_item(user.id)
      assert found.id == item.id
    end
  end

  describe "link_avatar_to_pinned_item/2" do
    test "creates moodboard photo link when none exists" do
      user = bare_user_fixture()
      {:ok, _pinned} = Moodboard.create_pinned_intro_item(user, "About me")

      photo =
        Animina.PhotosFixtures.approved_photo_fixture(%{owner_type: "User", owner_id: user.id})

      assert {:ok, moodboard_photo} = Moodboard.link_avatar_to_pinned_item(user.id, photo.id)
      assert moodboard_photo.photo_id == photo.id
    end

    test "updates existing moodboard photo link" do
      user = bare_user_fixture()
      {:ok, _pinned} = Moodboard.create_pinned_intro_item(user, "About me")

      photo1 =
        Animina.PhotosFixtures.approved_photo_fixture(%{owner_type: "User", owner_id: user.id})

      photo2 =
        Animina.PhotosFixtures.approved_photo_fixture(%{owner_type: "User", owner_id: user.id})

      {:ok, _} = Moodboard.link_avatar_to_pinned_item(user.id, photo1.id)
      {:ok, updated} = Moodboard.link_avatar_to_pinned_item(user.id, photo2.id)

      assert updated.photo_id == photo2.id
    end

    test "returns error if no pinned item exists" do
      user = bare_user_fixture()

      photo =
        Animina.PhotosFixtures.approved_photo_fixture(%{owner_type: "User", owner_id: user.id})

      assert {:error, :no_pinned_item} = Moodboard.link_avatar_to_pinned_item(user.id, photo.id)
    end
  end

  describe "unlink_avatar_from_pinned_item/1" do
    test "removes moodboard photo but keeps the item" do
      user = bare_user_fixture()
      {:ok, pinned} = Moodboard.create_pinned_intro_item(user, "About me")

      photo =
        Animina.PhotosFixtures.approved_photo_fixture(%{owner_type: "User", owner_id: user.id})

      {:ok, _} = Moodboard.link_avatar_to_pinned_item(user.id, photo.id)

      assert :ok = Moodboard.unlink_avatar_from_pinned_item(user.id)

      # Item should still exist but without photo
      refreshed = Moodboard.get_pinned_item(user.id)
      assert refreshed.id == pinned.id
      assert refreshed.moodboard_photo == nil
      assert refreshed.moodboard_story.content == "About me"
    end

    test "returns ok even if no pinned item exists" do
      user = bare_user_fixture()

      assert :ok = Moodboard.unlink_avatar_from_pinned_item(user.id)
    end
  end

  describe "update_positions/2 with pinned items" do
    test "excludes pinned items from reordering" do
      user = bare_user_fixture()
      {:ok, pinned} = Moodboard.create_pinned_intro_item(user, "About me")
      item1 = moodboard_item_fixture(%{user_id: user.id, position: 2})
      item2 = moodboard_item_fixture(%{user_id: user.id, position: 3})

      # Try to reorder including the pinned item
      {:ok, :ok} = Moodboard.update_positions(user.id, [item2.id, pinned.id, item1.id])

      # Pinned item should still be at position 1
      refreshed_pinned = Moodboard.get_item(pinned.id)
      assert refreshed_pinned.position == 1

      # Other items should be reordered starting at position 2
      refreshed1 = Moodboard.get_item(item1.id)
      refreshed2 = Moodboard.get_item(item2.id)
      assert refreshed2.position == 2
      assert refreshed1.position == 3
    end

    test "starts non-pinned items at position 2 when pinned item exists" do
      user = bare_user_fixture()
      {:ok, _pinned} = Moodboard.create_pinned_intro_item(user, "About me")
      item1 = moodboard_item_fixture(%{user_id: user.id, position: 2})
      item2 = moodboard_item_fixture(%{user_id: user.id, position: 3})

      {:ok, :ok} = Moodboard.update_positions(user.id, [item1.id, item2.id])

      refreshed1 = Moodboard.get_item(item1.id)
      refreshed2 = Moodboard.get_item(item2.id)
      assert refreshed1.position == 2
      assert refreshed2.position == 3
    end
  end

  describe "registration creates pinned intro item" do
    test "new user has a pinned intro item after registration" do
      # Use the regular user_fixture which goes through registration
      user = user_fixture()

      pinned = Moodboard.get_pinned_item(user.id)
      assert pinned != nil
      assert pinned.pinned == true
      assert pinned.position == 1
      assert pinned.item_type == "combined"
      assert pinned.moodboard_story != nil
    end
  end
end
