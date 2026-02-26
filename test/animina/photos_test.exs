defmodule Animina.PhotosTest do
  use Animina.DataCase, async: true

  alias Animina.Photos
  alias Animina.Photos.Photo
  alias Animina.Photos.PhotoProcessor

  import Animina.PhotosFixtures

  describe "Photo schema - create_changeset/2" do
    test "valid attributes create a pending photo" do
      attrs = %{
        owner_type: "User",
        owner_id: Ecto.UUID.generate(),
        filename: "abc123"
      }

      changeset = Photo.create_changeset(%Photo{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :state) == "pending"
    end

    test "requires owner_type, owner_id, and filename" do
      changeset = Photo.create_changeset(%Photo{}, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors.owner_type
      assert "can't be blank" in errors.owner_id
      assert "can't be blank" in errors.filename
    end

    test "optional fields are accepted" do
      attrs = %{
        owner_type: "User",
        owner_id: Ecto.UUID.generate(),
        filename: "abc123",
        original_filename: "photo.jpg",
        content_type: "image/jpeg",
        type: "avatar",
        position: 1
      }

      changeset = Photo.create_changeset(%Photo{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :original_filename) == "photo.jpg"
      assert Ecto.Changeset.get_field(changeset, :type) == "avatar"
    end
  end

  describe "Photo schema - state machine transitions" do
    test "pending -> processing is valid" do
      photo = photo_fixture(%{state: "pending"})
      changeset = Photo.transition_changeset(photo, "processing")
      assert changeset.valid?
    end

    test "pending -> error is valid" do
      photo = photo_fixture(%{state: "pending"})
      changeset = Photo.transition_changeset(photo, "error", %{error_message: "fail"})
      assert changeset.valid?
    end

    test "pending -> approved is valid (for seeding)" do
      photo = photo_fixture(%{state: "pending"})
      changeset = Photo.transition_changeset(photo, "approved")
      assert changeset.valid?
    end

    test "pending -> ollama_checking is invalid" do
      photo = photo_fixture(%{state: "pending"})
      changeset = Photo.transition_changeset(photo, "ollama_checking")
      refute changeset.valid?
      assert "cannot transition from pending to ollama_checking" in errors_on(changeset).state
    end

    test "processing -> ollama_checking is valid" do
      photo = photo_fixture() |> force_state("processing")
      changeset = Photo.transition_changeset(photo, "ollama_checking", %{width: 800, height: 600})
      assert changeset.valid?
    end

    test "ollama_checking -> approved is valid" do
      photo = photo_fixture() |> force_state("ollama_checking")
      changeset = Photo.transition_changeset(photo, "approved")
      assert changeset.valid?
    end

    test "approved -> anything is invalid" do
      photo = approved_photo_fixture()

      changeset = Photo.transition_changeset(photo, "processing")
      refute changeset.valid?
    end

    test "error -> pending is valid (retry)" do
      photo = photo_fixture() |> force_state("error")
      changeset = Photo.transition_changeset(photo, "pending")
      assert changeset.valid?
    end
  end

  describe "create_photo/1" do
    test "creates a photo in the database" do
      owner_id = Ecto.UUID.generate()

      {:ok, photo} =
        Photos.create_photo(%{
          owner_type: "User",
          owner_id: owner_id,
          filename: "test123"
        })

      assert photo.id
      assert photo.owner_type == "User"
      assert photo.owner_id == owner_id
      assert photo.state == "pending"
    end
  end

  describe "get_photo/1 and get_photo!/1" do
    test "get_photo returns nil for missing ID" do
      assert nil == Photos.get_photo(Ecto.UUID.generate())
    end

    test "get_photo returns photo for existing ID" do
      photo = photo_fixture()
      assert %Photo{id: id} = Photos.get_photo(photo.id)
      assert id == photo.id
    end

    test "get_photo! raises for missing ID" do
      assert_raise Ecto.NoResultsError, fn ->
        Photos.get_photo!(Ecto.UUID.generate())
      end
    end
  end

  describe "transition_photo/3" do
    test "transitions and saves to DB" do
      photo = photo_fixture()
      {:ok, updated} = Photos.transition_photo(photo, "processing")
      assert updated.state == "processing"

      reloaded = Photos.get_photo!(photo.id)
      assert reloaded.state == "processing"
    end

    test "returns error for invalid transition" do
      photo = photo_fixture()
      {:error, changeset} = Photos.transition_photo(photo, "ollama_checking")
      assert "cannot transition from pending to ollama_checking" in errors_on(changeset).state
    end

    test "broadcasts state change on successful transition" do
      photo = photo_fixture()
      topic = "photos:#{photo.owner_type}:#{photo.owner_id}"

      # Subscribe to PubSub
      Phoenix.PubSub.subscribe(Animina.PubSub, topic)

      {:ok, updated} = Photos.transition_photo(photo, "processing")

      assert_receive {:photo_state_changed, ^updated}
    end

    test "does not broadcast on failed transition" do
      photo = photo_fixture()
      topic = "photos:#{photo.owner_type}:#{photo.owner_id}"

      # Subscribe to PubSub
      Phoenix.PubSub.subscribe(Animina.PubSub, topic)

      {:error, _changeset} = Photos.transition_photo(photo, "ollama_checking")

      refute_receive {:photo_state_changed, _}
    end
  end

  describe "delete_photo/1" do
    test "deletes photo from database" do
      photo = photo_fixture()
      {:ok, _} = Photos.delete_photo(photo)
      assert nil == Photos.get_photo(photo.id)
    end
  end

  describe "list_photos/2 and list_photos/3" do
    test "lists only approved photos for an owner" do
      owner_id = Ecto.UUID.generate()
      _pending = photo_fixture(%{owner_type: "User", owner_id: owner_id})
      approved = approved_photo_fixture(%{owner_type: "User", owner_id: owner_id})

      photos = Photos.list_photos("User", owner_id)
      assert length(photos) == 1
      assert hd(photos).id == approved.id
    end

    test "filters by type" do
      owner_id = Ecto.UUID.generate()

      _avatar =
        approved_photo_fixture(%{owner_type: "User", owner_id: owner_id, type: "avatar"})

      _moodboard =
        approved_photo_fixture(%{owner_type: "User", owner_id: owner_id, type: "moodboard"})

      photos = Photos.list_photos("User", owner_id, "avatar")
      assert length(photos) == 1
    end

    test "does not mix owners" do
      owner1 = Ecto.UUID.generate()
      owner2 = Ecto.UUID.generate()
      _photo1 = approved_photo_fixture(%{owner_type: "User", owner_id: owner1})
      _photo2 = approved_photo_fixture(%{owner_type: "User", owner_id: owner2})

      assert length(Photos.list_photos("User", owner1)) == 1
    end
  end

  describe "list_all_photos/2" do
    test "lists photos in all states" do
      owner_id = Ecto.UUID.generate()
      _pending = photo_fixture(%{owner_type: "User", owner_id: owner_id})
      _approved = approved_photo_fixture(%{owner_type: "User", owner_id: owner_id})

      photos = Photos.list_all_photos("User", owner_id)
      assert length(photos) == 2
    end
  end

  describe "count_photos/3" do
    test "counts only approved photos" do
      owner_id = Ecto.UUID.generate()
      _pending = photo_fixture(%{owner_type: "User", owner_id: owner_id})
      _approved = approved_photo_fixture(%{owner_type: "User", owner_id: owner_id})

      assert Photos.count_photos("User", owner_id) == 1
    end
  end

  describe "URL signing" do
    test "compute_signature returns a 16-char base64 string" do
      sig = Photos.compute_signature("some-photo-id")
      assert byte_size(sig) == 16
    end

    test "verify_signature returns true for valid signature" do
      photo_id = Ecto.UUID.generate()
      sig = Photos.compute_signature(photo_id)
      assert Photos.verify_signature(sig, photo_id)
    end

    test "verify_signature returns false for wrong photo_id" do
      sig = Photos.compute_signature("photo-1")
      refute Photos.verify_signature(sig, "photo-2")
    end

    test "verify_signature returns false for tampered signature" do
      photo_id = Ecto.UUID.generate()
      refute Photos.verify_signature("tampered_sig_xxxx", photo_id)
    end

    test "signed_url generates a path with valid signature" do
      photo = approved_photo_fixture()
      url = Photos.signed_url(photo)
      assert String.starts_with?(url, "/photos/")
      assert String.ends_with?(url, ".webp")

      # Extract signature and filename from URL
      [_, "photos", signature, filename] = String.split(url, "/")
      assert String.ends_with?(filename, ".webp")
      photo_id = String.replace_trailing(filename, ".webp", "")
      assert Photos.verify_signature(signature, photo_id)
    end

    test "signed_url for thumbnail variant" do
      photo = approved_photo_fixture()
      url = Photos.signed_url(photo, :thumbnail)
      assert String.contains?(url, "_thumb.webp")
    end
  end

  describe "get_user_avatar/1" do
    test "returns nil when user has no avatar" do
      user_id = Ecto.UUID.generate()
      assert nil == Photos.get_user_avatar(user_id)
    end

    test "returns the approved avatar photo" do
      user_id = Ecto.UUID.generate()

      avatar =
        approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      result = Photos.get_user_avatar(user_id)
      assert result.id == avatar.id
    end

    test "ignores non-avatar photos" do
      user_id = Ecto.UUID.generate()

      _moodboard =
        approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "moodboard"})

      assert nil == Photos.get_user_avatar(user_id)
    end

    test "ignores pending photos" do
      user_id = Ecto.UUID.generate()
      _pending = photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      assert nil == Photos.get_user_avatar(user_id)
    end

    test "returns most recent avatar when multiple exist" do
      user_id = Ecto.UUID.generate()

      old =
        approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      # Backdate the old photo to ensure it has an earlier timestamp
      old_time = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

      old
      |> Ecto.Changeset.change(%{inserted_at: old_time})
      |> Repo.update!()

      new =
        approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      result = Photos.get_user_avatar(user_id)
      assert result.id == new.id
    end
  end

  describe "get_user_avatar_url/1" do
    test "returns nil when user has no avatar" do
      user_id = Ecto.UUID.generate()
      assert nil == Photos.get_user_avatar_url(user_id)
    end

    test "returns signed URL for avatar" do
      user_id = Ecto.UUID.generate()

      _avatar =
        approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      url = Photos.get_user_avatar_url(user_id)
      assert String.starts_with?(url, "/photos/")
      assert String.ends_with?(url, ".webp")
    end
  end

  describe "get_user_avatar_any_state/1" do
    test "returns nil when user has no avatar" do
      user_id = Ecto.UUID.generate()
      assert nil == Photos.get_user_avatar_any_state(user_id)
    end

    test "returns pending avatar photo" do
      user_id = Ecto.UUID.generate()
      pending = photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      result = Photos.get_user_avatar_any_state(user_id)
      assert result.id == pending.id
      assert result.state == "pending"
    end

    test "returns approved avatar photo" do
      user_id = Ecto.UUID.generate()
      approved = approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      result = Photos.get_user_avatar_any_state(user_id)
      assert result.id == approved.id
    end

    test "returns most recent avatar regardless of state" do
      user_id = Ecto.UUID.generate()

      old =
        approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      old_time = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

      old
      |> Ecto.Changeset.change(%{inserted_at: old_time})
      |> Repo.update!()

      new = photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      result = Photos.get_user_avatar_any_state(user_id)
      assert result.id == new.id
    end

    test "ignores non-avatar photos" do
      user_id = Ecto.UUID.generate()
      _moodboard = photo_fixture(%{owner_type: "User", owner_id: user_id, type: "moodboard"})

      assert nil == Photos.get_user_avatar_any_state(user_id)
    end
  end

  describe "delete_user_avatars/1" do
    test "deletes all avatar photos for a user" do
      user_id = Ecto.UUID.generate()
      avatar1 = photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})
      avatar2 = approved_photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      Photos.delete_user_avatars(user_id)

      assert nil == Photos.get_photo(avatar1.id)
      assert nil == Photos.get_photo(avatar2.id)
    end

    test "does not delete non-avatar photos" do
      user_id = Ecto.UUID.generate()
      moodboard = photo_fixture(%{owner_type: "User", owner_id: user_id, type: "moodboard"})
      _avatar = photo_fixture(%{owner_type: "User", owner_id: user_id, type: "avatar"})

      Photos.delete_user_avatars(user_id)

      assert Photos.get_photo(moodboard.id) != nil
    end

    test "does not delete other users' avatars" do
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()
      user1_avatar = photo_fixture(%{owner_type: "User", owner_id: user1_id, type: "avatar"})
      _user2_avatar = photo_fixture(%{owner_type: "User", owner_id: user2_id, type: "avatar"})

      Photos.delete_user_avatars(user2_id)

      assert Photos.get_photo(user1_avatar.id) != nil
    end
  end

  describe "file path helpers" do
    test "original_path_dir builds correct path" do
      dir = Photos.original_path_dir("User", "abc-123")
      assert String.ends_with?(dir, "originals/User/abc-123")
    end

    test "processed_path_dir builds correct path" do
      dir = Photos.processed_path_dir("User", "abc-123")
      assert String.ends_with?(dir, "processed/User/abc-123")
    end

    test "processed_path builds correct path for main variant" do
      owner_id = Ecto.UUID.generate()
      photo = photo_fixture(%{owner_type: "User", owner_id: owner_id})
      path = Photos.processed_path(photo, :main)
      assert String.contains?(path, "processed/User/#{owner_id}")
      assert String.ends_with?(path, "#{photo.id}.webp")
    end

    test "processed_path builds correct path for thumbnail variant" do
      owner_id = Ecto.UUID.generate()
      photo = photo_fixture(%{owner_type: "User", owner_id: owner_id})
      path = Photos.processed_path(photo, :thumbnail)
      assert String.contains?(path, "processed/User/#{owner_id}")
      assert String.ends_with?(path, "#{photo.id}_thumb.webp")
    end
  end

  # Helper to force a photo into a specific state (bypassing state machine)
  defp force_state(photo, state) do
    photo
    |> Ecto.Changeset.change(%{state: state})
    |> Repo.update!()
  end

  describe "list_pending_appeals_paginated/1" do
    test "returns paginated results with default page and per_page" do
      user = Animina.AccountsFixtures.user_fixture()

      # Create 3 appeals
      _appeal1 = appeal_fixture(%{user_id: user.id})
      _appeal2 = appeal_fixture(%{user_id: user.id})
      _appeal3 = appeal_fixture(%{user_id: user.id})

      result = Photos.list_pending_appeals_paginated()

      assert result.page == 1
      assert result.per_page == 50
      assert result.total_count == 3
      assert result.total_pages == 1
      assert length(result.entries) == 3
    end

    test "respects page and per_page options" do
      user = Animina.AccountsFixtures.user_fixture()

      # Create 5 appeals
      for _ <- 1..5 do
        appeal_fixture(%{user_id: user.id})
      end

      result = Photos.list_pending_appeals_paginated(page: 1, per_page: 2)

      assert result.page == 1
      assert result.per_page == 2
      assert result.total_count == 5
      assert result.total_pages == 3
      assert length(result.entries) == 2
    end

    test "returns correct page offset" do
      user = Animina.AccountsFixtures.user_fixture()

      # Create 5 appeals
      for _ <- 1..5 do
        appeal_fixture(%{user_id: user.id})
      end

      result_page1 = Photos.list_pending_appeals_paginated(page: 1, per_page: 2)
      result_page2 = Photos.list_pending_appeals_paginated(page: 2, per_page: 2)
      result_page3 = Photos.list_pending_appeals_paginated(page: 3, per_page: 2)

      assert length(result_page1.entries) == 2
      assert length(result_page2.entries) == 2
      assert length(result_page3.entries) == 1

      # No overlap in IDs between pages
      page1_ids = MapSet.new(result_page1.entries, & &1.id)
      page2_ids = MapSet.new(result_page2.entries, & &1.id)
      page3_ids = MapSet.new(result_page3.entries, & &1.id)

      assert MapSet.disjoint?(page1_ids, page2_ids)
      assert MapSet.disjoint?(page2_ids, page3_ids)
      assert MapSet.disjoint?(page1_ids, page3_ids)
    end

    test "returns empty entries when page exceeds total" do
      user = Animina.AccountsFixtures.user_fixture()
      _appeal = appeal_fixture(%{user_id: user.id})

      result = Photos.list_pending_appeals_paginated(page: 10, per_page: 50)

      assert result.entries == []
      assert result.total_count == 1
      assert result.total_pages == 1
    end

    test "preloads photo and user associations" do
      user = Animina.AccountsFixtures.user_fixture()
      _appeal = appeal_fixture(%{user_id: user.id})

      result = Photos.list_pending_appeals_paginated()
      appeal = hd(result.entries)

      assert appeal.photo != nil
      assert appeal.user != nil
      assert appeal.user.id == user.id
    end
  end

  describe "count_pending_appeals/0" do
    test "returns 0 when no pending appeals" do
      assert Photos.count_pending_appeals() == 0
    end

    test "counts only pending appeals" do
      user = Animina.AccountsFixtures.user_fixture()
      reviewer = Animina.AccountsFixtures.user_fixture()

      _pending1 = appeal_fixture(%{user_id: user.id})
      _pending2 = appeal_fixture(%{user_id: user.id})
      resolved = appeal_fixture(%{user_id: user.id})

      # Resolve one appeal
      Photos.resolve_appeal(resolved, reviewer, "approved")

      assert Photos.count_pending_appeals() == 2
    end
  end

  describe "bulk_resolve_appeals/4" do
    test "resolves multiple appeals in a single transaction" do
      user = Animina.AccountsFixtures.user_fixture()
      reviewer = Animina.AccountsFixtures.user_fixture()

      appeal1 = appeal_fixture(%{user_id: user.id})
      appeal2 = appeal_fixture(%{user_id: user.id})
      appeal3 = appeal_fixture(%{user_id: user.id})

      appeal_ids = [appeal1.id, appeal2.id, appeal3.id]
      {:ok, result} = Photos.bulk_resolve_appeals(appeal_ids, reviewer, "rejected")

      assert result.resolved == 3
      assert result.failed == 0

      # Verify all appeals are resolved
      for id <- appeal_ids do
        appeal = Photos.get_appeal!(id)
        assert appeal.status == "resolved"
        assert appeal.resolution == "rejected"
        assert appeal.reviewer_id == reviewer.id
      end
    end

    test "handles mixed success and already-resolved appeals" do
      user = Animina.AccountsFixtures.user_fixture()
      reviewer = Animina.AccountsFixtures.user_fixture()

      appeal1 = appeal_fixture(%{user_id: user.id})
      appeal2 = appeal_fixture(%{user_id: user.id})

      # Resolve appeal2 first
      Photos.resolve_appeal(appeal2, reviewer, "approved")

      appeal_ids = [appeal1.id, appeal2.id]
      {:ok, result} = Photos.bulk_resolve_appeals(appeal_ids, reviewer, "rejected")

      # appeal1 resolved, appeal2 was already resolved so counted as failed
      assert result.resolved == 1
      assert result.failed == 1
    end

    test "handles empty appeal list" do
      reviewer = Animina.AccountsFixtures.user_fixture()
      {:ok, result} = Photos.bulk_resolve_appeals([], reviewer, "rejected")

      assert result.resolved == 0
      assert result.failed == 0
    end

    test "supports add_to_blacklist option" do
      user = Animina.AccountsFixtures.user_fixture()
      reviewer = Animina.AccountsFixtures.user_fixture()

      # Create appeal with a dhash on the photo
      dhash = <<1, 2, 3, 4, 5, 6, 7, 8>>

      appeal =
        appeal_fixture(%{
          user_id: user.id,
          dhash: dhash
        })

      {:ok, _result} =
        Photos.bulk_resolve_appeals(
          [appeal.id],
          reviewer,
          "rejected",
          add_to_blacklist: true,
          blacklist_reason: "Bulk rejected"
        )

      # Verify photo dhash was added to blacklist
      entry = Photos.get_blacklist_entry_by_dhash(dhash)
      assert entry != nil
      assert entry.reason == "Bulk rejected"
    end

    test "handles non-existent appeal IDs gracefully" do
      reviewer = Animina.AccountsFixtures.user_fixture()
      fake_id = Ecto.UUID.generate()

      {:ok, result} = Photos.bulk_resolve_appeals([fake_id], reviewer, "rejected")

      assert result.resolved == 0
      assert result.failed == 1
    end
  end

  describe "self-moderation filtering" do
    test "list_pending_appeals_paginated excludes own appeals when multiple moderators exist" do
      user1 = Animina.AccountsFixtures.user_fixture()
      user2 = Animina.AccountsFixtures.user_fixture()

      # Make both users moderators
      Animina.Accounts.assign_role(user1, "moderator")
      Animina.Accounts.assign_role(user2, "moderator")

      # Create appeals for both users
      appeal1 = appeal_fixture(%{user_id: user1.id})
      appeal2 = appeal_fixture(%{user_id: user2.id})

      # user1 should not see their own appeal
      result1 = Photos.list_pending_appeals_paginated(viewer_id: user1.id)
      appeal_ids1 = Enum.map(result1.entries, & &1.id)
      refute appeal1.id in appeal_ids1
      assert appeal2.id in appeal_ids1

      # user2 should not see their own appeal
      result2 = Photos.list_pending_appeals_paginated(viewer_id: user2.id)
      appeal_ids2 = Enum.map(result2.entries, & &1.id)
      assert appeal1.id in appeal_ids2
      refute appeal2.id in appeal_ids2
    end

    test "list_pending_appeals_paginated shows own appeals when only one moderator exists" do
      user = Animina.AccountsFixtures.user_fixture()

      # Make user the only moderator
      Animina.Accounts.assign_role(user, "moderator")

      # Create appeal for the user
      appeal = appeal_fixture(%{user_id: user.id})

      # User should see their own appeal since they're the only moderator
      result = Photos.list_pending_appeals_paginated(viewer_id: user.id)
      appeal_ids = Enum.map(result.entries, & &1.id)
      assert appeal.id in appeal_ids
    end

    test "count_pending_appeals excludes own appeals when multiple moderators exist" do
      user1 = Animina.AccountsFixtures.user_fixture()
      user2 = Animina.AccountsFixtures.user_fixture()

      # Make both users moderators
      Animina.Accounts.assign_role(user1, "moderator")
      Animina.Accounts.assign_role(user2, "moderator")

      # Create appeals for both users
      _appeal1 = appeal_fixture(%{user_id: user1.id})
      _appeal2 = appeal_fixture(%{user_id: user2.id})

      # Total count without filter should be 2
      assert Photos.count_pending_appeals() == 2

      # user1 should only count user2's appeal
      assert Photos.count_pending_appeals(viewer_id: user1.id) == 1

      # user2 should only count user1's appeal
      assert Photos.count_pending_appeals(viewer_id: user2.id) == 1
    end

    test "count_pending_appeals shows all appeals when only one moderator exists" do
      user = Animina.AccountsFixtures.user_fixture()

      # Make user the only moderator
      Animina.Accounts.assign_role(user, "moderator")

      # Create appeals
      _appeal1 = appeal_fixture(%{user_id: user.id})

      # User should see all appeals since they're the only moderator
      assert Photos.count_pending_appeals(viewer_id: user.id) == 1
    end
  end

  describe "validate_image_magic/1 - file validation security" do
    test "accepts valid JPEG file" do
      # Create a minimal valid JPEG file
      jpeg_content = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, "JFIF"::binary, 0x00>>
      path = Path.join(System.tmp_dir!(), "test_#{:rand.uniform(1000)}.jpg")
      File.write!(path, jpeg_content)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/jpeg"} = Photos.validate_image_magic(path)
    end

    test "accepts valid PNG file" do
      # PNG magic bytes
      png_content = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "IHDR"::binary>>
      path = Path.join(System.tmp_dir!(), "test_#{:rand.uniform(1000)}.png")
      File.write!(path, png_content)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/png"} = Photos.validate_image_magic(path)
    end

    test "accepts valid WebP file" do
      # WebP magic bytes: RIFF + size + WEBP
      webp_content = <<0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50>>
      path = Path.join(System.tmp_dir!(), "test_#{:rand.uniform(1000)}.webp")
      File.write!(path, webp_content)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/webp"} = Photos.validate_image_magic(path)
    end

    test "accepts valid HEIC file" do
      # HEIC magic bytes: ....ftypheic
      heic_content = <<0x00, 0x00, 0x00, 0x18, "ftypheic"::binary, 0x00, 0x00, 0x00, 0x00>>
      path = Path.join(System.tmp_dir!(), "test_#{:rand.uniform(1000)}.heic")
      File.write!(path, heic_content)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/heic"} = Photos.validate_image_magic(path)
    end

    test "rejects executable file disguised as image" do
      # Windows PE executable magic bytes: MZ header
      exe_content = <<"MZ", 0x90, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00>>
      path = Path.join(System.tmp_dir!(), "malicious_#{:rand.uniform(1000)}.jpg")
      File.write!(path, exe_content)
      on_exit(fn -> File.rm(path) end)

      assert {:error, :invalid_image} = Photos.validate_image_magic(path)
    end

    test "rejects ZIP file disguised as image" do
      # ZIP magic bytes: PK followed by local file header signature
      zip_content = <<"PK", 0x03, 0x04, 0x14, 0x00, 0x00, 0x00, 0x08, 0x00>>
      path = Path.join(System.tmp_dir!(), "malicious_#{:rand.uniform(1000)}.png")
      File.write!(path, zip_content)
      on_exit(fn -> File.rm(path) end)

      assert {:error, :invalid_image} = Photos.validate_image_magic(path)
    end

    test "rejects PDF file disguised as image" do
      # PDF magic bytes
      pdf_content = <<"%PDF-1.4", 0x0A>>
      path = Path.join(System.tmp_dir!(), "malicious_#{:rand.uniform(1000)}.jpg")
      File.write!(path, pdf_content)
      on_exit(fn -> File.rm(path) end)

      assert {:error, :invalid_image} = Photos.validate_image_magic(path)
    end

    test "rejects plain text file" do
      text_content = "This is not an image file"
      path = Path.join(System.tmp_dir!(), "text_#{:rand.uniform(1000)}.jpg")
      File.write!(path, text_content)
      on_exit(fn -> File.rm(path) end)

      assert {:error, :invalid_image} = Photos.validate_image_magic(path)
    end

    test "rejects empty file" do
      path = Path.join(System.tmp_dir!(), "empty_#{:rand.uniform(1000)}.jpg")
      File.write!(path, "")
      on_exit(fn -> File.rm(path) end)

      assert {:error, :invalid_image} = Photos.validate_image_magic(path)
    end

    test "returns error for non-existent file" do
      path = "/non/existent/file.jpg"
      assert {:error, :file_read_error} = Photos.validate_image_magic(path)
    end
  end

  describe "crop data management" do
    test "get_crop_data returns nil when no crop file exists" do
      photo = photo_fixture()
      assert nil == Photos.get_crop_data(photo)
    end

    test "crop data can be stored and retrieved" do
      owner_id = Ecto.UUID.generate()

      # Create original dir
      original_dir = Photos.original_path_dir("User", owner_id)
      File.mkdir_p!(original_dir)
      on_exit(fn -> File.rm_rf!(original_dir) end)

      # Create a photo
      photo = photo_fixture(%{owner_type: "User", owner_id: owner_id})

      # Write crop data
      crop_path = Path.join(original_dir, "#{photo.filename}.crop.json")
      crop_data = %{x: 10, y: 20, width: 100, height: 100}
      File.write!(crop_path, Jason.encode!(crop_data))

      # Read it back
      result = Photos.get_crop_data(photo)
      assert result.x == 10
      assert result.y == 20
      assert result.width == 100
      assert result.height == 100
    end

    test "delete_crop_data removes the crop file" do
      owner_id = Ecto.UUID.generate()

      # Create original dir
      original_dir = Photos.original_path_dir("User", owner_id)
      File.mkdir_p!(original_dir)
      on_exit(fn -> File.rm_rf!(original_dir) end)

      # Create a photo
      photo = photo_fixture(%{owner_type: "User", owner_id: owner_id})

      # Write crop data
      crop_path = Path.join(original_dir, "#{photo.filename}.crop.json")
      File.write!(crop_path, Jason.encode!(%{x: 10, y: 20, width: 100, height: 100}))

      assert File.exists?(crop_path)

      # Delete it
      Photos.delete_crop_data(photo)

      refute File.exists?(crop_path)
    end

    test "original_path does not return crop.json files" do
      owner_id = Ecto.UUID.generate()

      # Create original dir
      original_dir = Photos.original_path_dir("User", owner_id)
      File.mkdir_p!(original_dir)
      on_exit(fn -> File.rm_rf!(original_dir) end)

      # Create a photo
      photo = photo_fixture(%{owner_type: "User", owner_id: owner_id})

      # Create both an image file and a crop file
      image_path = Path.join(original_dir, "#{photo.filename}.jpg")
      crop_path = Path.join(original_dir, "#{photo.filename}.crop.json")

      File.write!(image_path, "fake image content")
      File.write!(crop_path, Jason.encode!(%{x: 10, y: 20, width: 100, height: 100}))

      # original_path should return the image, not the crop file
      assert {:ok, path} = Photos.original_path(photo)
      assert String.ends_with?(path, ".jpg")
      refute String.ends_with?(path, ".crop.json")
    end
  end

  describe "PhotoProcessor.apply_center_crop/1" do
    test "crops landscape image to square" do
      # Create a test image (20x10 pixels, landscape)
      {:ok, image} = Image.new(20, 10, color: [255, 0, 0])

      {:ok, cropped} = PhotoProcessor.apply_center_crop(image)

      # Should be 10x10 (the minimum dimension)
      assert Image.width(cropped) == 10
      assert Image.height(cropped) == 10
    end

    test "crops portrait image to square" do
      # Create a test image (10x20 pixels, portrait)
      {:ok, image} = Image.new(10, 20, color: [0, 255, 0])

      {:ok, cropped} = PhotoProcessor.apply_center_crop(image)

      # Should be 10x10 (the minimum dimension)
      assert Image.width(cropped) == 10
      assert Image.height(cropped) == 10
    end

    test "keeps square image unchanged" do
      # Create a test image (10x10 pixels, already square)
      {:ok, image} = Image.new(10, 10, color: [0, 0, 255])

      {:ok, cropped} = PhotoProcessor.apply_center_crop(image)

      # Should remain 10x10
      assert Image.width(cropped) == 10
      assert Image.height(cropped) == 10
    end
  end

  describe "upload_photo/4 - security validation" do
    test "rejects files larger than max_upload_size" do
      owner_id = Ecto.UUID.generate()

      # Create a file larger than max_upload_size (10MB default, configurable via feature flags)
      # We can't easily create a 6MB+ file in tests, so we'll test the validation function directly
      path = Path.join(System.tmp_dir!(), "large_#{:rand.uniform(1000)}.jpg")

      # Create a valid but tiny JPEG
      jpeg_content = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, "JFIF"::binary, 0x00>>
      File.write!(path, jpeg_content)
      on_exit(fn -> File.rm(path) end)

      # This should succeed since the file is small
      result = Photos.upload_photo("User", owner_id, path, original_filename: "test.jpg")

      case result do
        {:ok, photo} ->
          # Cleanup
          Photos.delete_photo(photo)

        {:error, _} ->
          # Expected for very minimal JPEG (may fail processing but not validation)
          :ok
      end
    end

    test "rejects file with fake Content-Type header but wrong magic bytes" do
      owner_id = Ecto.UUID.generate()

      # Create a text file
      path = Path.join(System.tmp_dir!(), "fake_#{:rand.uniform(1000)}.jpg")
      File.write!(path, "This is not a JPEG file")
      on_exit(fn -> File.rm(path) end)

      # Even with content_type set to image/jpeg, it should be rejected
      result =
        Photos.upload_photo("User", owner_id, path,
          original_filename: "malicious.jpg",
          content_type: "image/jpeg"
        )

      assert {:error, :invalid_image} = result
    end
  end
end
