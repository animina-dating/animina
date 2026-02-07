defmodule Animina.Accounts.ProfileCompletenessTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.ProfileCompleteness
  alias Animina.Moodboard.Items
  alias Animina.Traits

  import Animina.AccountsFixtures
  import Animina.PhotosFixtures
  import Animina.TraitsFixtures

  describe "compute/1" do
    test "default user_fixture has profile_info, location, and partner_preferences" do
      user = user_fixture(language: "en")
      result = ProfileCompleteness.compute(user)

      assert result.total_count == 6
      assert result.items.profile_info == true
      assert result.items.location == true
      assert result.items.partner_preferences == true
      assert result.items.moodboard == false
      assert result.items.profile_photo == false
      assert result.items.flags == false
      assert result.completed_count == 3
      assert result.location_count == 1
    end

    test "profile_photo is true when approved avatar exists" do
      user = user_fixture(language: "en")
      _avatar = approved_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      result = ProfileCompleteness.compute(user)
      assert result.items.profile_photo == true
    end

    test "profile_photo is false when avatar is pending (not approved)" do
      user = user_fixture(language: "en")
      _avatar = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      result = ProfileCompleteness.compute(user)
      assert result.items.profile_photo == false
    end

    test "profile_info is false when height is nil" do
      user = user_fixture(language: "en")
      # Height is NOT NULL in the DB, so test with a struct override
      result = ProfileCompleteness.compute(%{user | height: nil})
      assert result.items.profile_info == false
    end

    test "location is false when user has no locations" do
      user = user_fixture(language: "en", locations: [])

      result = ProfileCompleteness.compute(user)
      assert result.items.location == false
      assert result.location_count == 0
    end

    test "partner_preferences is false when preferred_partner_gender is empty" do
      user = user_fixture(language: "en", preferred_partner_gender: [])

      result = ProfileCompleteness.compute(user)
      assert result.items.partner_preferences == false
    end

    test "flags is true when user has at least one non-inherited flag" do
      user = user_fixture(language: "en")
      category = category_fixture()
      flag = flag_fixture(%{category_id: category.id})

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          position: 1
        })

      result = ProfileCompleteness.compute(user)
      assert result.items.flags == true
    end

    test "flags is false when user has no flags" do
      user = user_fixture(language: "en")

      result = ProfileCompleteness.compute(user)
      assert result.items.flags == false
    end

    test "moodboard is true when user has at least 2 moodboard items" do
      user = user_fixture(language: "en")
      # user_fixture creates 1 pinned intro item; add a second
      {:ok, _} = Items.create_story_item(user, "My second story")

      result = ProfileCompleteness.compute(user)
      assert result.items.moodboard == true
    end

    test "moodboard is false when user has only 1 moodboard item" do
      # Default user_fixture creates only the pinned intro item
      user = user_fixture(language: "en")

      result = ProfileCompleteness.compute(user)
      assert result.items.moodboard == false
    end

    test "completed_count is 6 when all items are complete" do
      user = user_fixture(language: "en")
      # user_fixture already gives: profile_info, location, partner_preferences
      _avatar = approved_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
      {:ok, _} = Items.create_story_item(user, "Second moodboard item")

      category = category_fixture()
      flag = flag_fixture(%{category_id: category.id})

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          position: 1
        })

      result = ProfileCompleteness.compute(user)
      assert result.completed_count == 6
      assert result.total_count == 6
      assert Enum.all?(Map.values(result.items), & &1)
    end
  end
end
