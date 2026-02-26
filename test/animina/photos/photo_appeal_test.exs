defmodule Animina.Photos.PhotoAppealTest do
  use Animina.DataCase, async: true

  alias Animina.Photos
  alias Animina.Photos.PhotoAppeal

  import Animina.AccountsFixtures
  import Animina.PhotosFixtures

  describe "create_appeal/3" do
    test "creates appeal and transitions photo to appeal_pending" do
      user = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      assert {:ok, %{appeal: appeal, photo: updated_photo}} =
               Photos.create_appeal(photo, user, "My face is clearly visible")

      assert appeal.photo_id == photo.id
      assert appeal.user_id == user.id
      assert appeal.status == "pending"
      assert appeal.appeal_reason == "My face is clearly visible"
      assert updated_photo.state == "appeal_pending"
    end

    test "creates appeal without reason" do
      user = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      assert {:ok, %{appeal: appeal}} = Photos.create_appeal(photo, user)
      assert appeal.appeal_reason == nil
    end

    test "logs appeal_created event" do
      user = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, %{photo: updated_photo}} = Photos.create_appeal(photo, user, "My face is there")

      history = Photos.get_photo_history(updated_photo.id)
      appeal_event = Enum.find(history, &(&1.event_type == "appeal_created"))

      assert appeal_event
      assert appeal_event.actor_type == "user"
      assert appeal_event.actor_id == user.id
    end
  end

  describe "list_pending_appeals/0" do
    test "returns pending appeals" do
      user = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, _} = Photos.create_appeal(photo, user)

      appeals = Photos.list_pending_appeals()
      assert length(appeals) == 1
      assert hd(appeals).status == "pending"
    end

    test "does not return resolved appeals" do
      user = user_fixture()
      reviewer = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, %{appeal: appeal}} = Photos.create_appeal(photo, user)
      {:ok, _} = Photos.resolve_appeal(appeal, reviewer, "approved")

      appeals = Photos.list_pending_appeals()
      assert Enum.empty?(appeals)
    end
  end

  describe "resolve_appeal/4" do
    test "approves appeal and transitions photo to approved" do
      user = user_fixture()
      reviewer = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, %{appeal: appeal}} = Photos.create_appeal(photo, user)

      assert {:ok, %{appeal: resolved, photo: updated_photo}} =
               Photos.resolve_appeal(appeal, reviewer, "approved", reviewer_notes: "Face visible")

      assert resolved.status == "resolved"
      assert resolved.resolution == "approved"
      assert resolved.reviewer_id == reviewer.id
      assert resolved.reviewer_notes == "Face visible"
      assert resolved.resolved_at
      assert updated_photo.state == "approved"
    end

    test "rejects appeal and transitions photo to appeal_rejected" do
      user = user_fixture()
      reviewer = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, %{appeal: appeal}} = Photos.create_appeal(photo, user)

      assert {:ok, %{appeal: resolved, photo: updated_photo}} =
               Photos.resolve_appeal(appeal, reviewer, "rejected",
                 reviewer_notes: "Still no face"
               )

      assert resolved.status == "resolved"
      assert resolved.resolution == "rejected"
      assert updated_photo.state == "appeal_rejected"
    end

    test "logs appeal resolution events" do
      user = user_fixture()
      reviewer = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, %{appeal: appeal}} = Photos.create_appeal(photo, user)

      {:ok, %{photo: updated_photo}} =
        Photos.resolve_appeal(appeal, reviewer, "approved", reviewer_notes: "OK")

      history = Photos.get_photo_history(updated_photo.id)
      approval_event = Enum.find(history, &(&1.event_type == "appeal_approved"))

      assert approval_event
      assert approval_event.actor_id == reviewer.id
    end
  end

  describe "has_pending_appeal?/1" do
    test "returns true when photo has pending appeal" do
      user = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, _} = Photos.create_appeal(photo, user)

      assert Photos.has_pending_appeal?(photo.id)
    end

    test "returns false when photo has no appeal" do
      photo = photo_fixture()
      refute Photos.has_pending_appeal?(photo.id)
    end

    test "returns false when appeal is resolved" do
      user = user_fixture()
      reviewer = user_fixture()

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, %{appeal: appeal}} = Photos.create_appeal(photo, user)
      {:ok, _} = Photos.resolve_appeal(appeal, reviewer, "approved")

      refute Photos.has_pending_appeal?(photo.id)
    end
  end

  describe "PhotoAppeal schema" do
    test "create_changeset validates required fields" do
      changeset = PhotoAppeal.create_changeset(%PhotoAppeal{}, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors.photo_id
      assert "can't be blank" in errors.user_id
    end

    test "resolve_changeset validates required fields" do
      appeal = %PhotoAppeal{status: "pending"}
      changeset = PhotoAppeal.resolve_changeset(appeal, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors.reviewer_id
      assert "can't be blank" in errors.resolution
    end

    test "resolve_changeset validates resolution values" do
      appeal = %PhotoAppeal{status: "pending"}

      changeset =
        PhotoAppeal.resolve_changeset(appeal, %{
          reviewer_id: Ecto.UUID.generate(),
          resolution: "invalid"
        })

      errors = errors_on(changeset)

      assert "is invalid" in errors.resolution
    end
  end
end
