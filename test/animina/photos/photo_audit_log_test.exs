defmodule Animina.Photos.PhotoAuditLogTest do
  use Animina.DataCase

  alias Animina.Photos
  alias Animina.Photos.PhotoAuditLog

  import Animina.AccountsFixtures
  import Animina.PhotosFixtures

  describe "log_event/5" do
    test "creates an audit log entry" do
      photo = photo_fixture()

      assert {:ok, log} =
               Photos.log_event(photo, "photo_uploaded", "user", nil, %{filename: "test.jpg"})

      assert log.photo_id == photo.id
      assert log.event_type == "photo_uploaded"
      assert log.actor_type == "user"
      # Details are stored with string keys due to JSON serialization
      assert log.details["filename"] == "test.jpg" || log.details[:filename] == "test.jpg"
      assert log.inserted_at
    end

    test "creates entry with actor_id" do
      user = user_fixture()
      photo = photo_fixture()

      {:ok, log} =
        Photos.log_event(photo, "appeal_created", "user", user.id, %{reason: "my face is there"})

      assert log.actor_id == user.id
    end

    test "creates entry without actor_id for system events" do
      photo = photo_fixture()

      {:ok, log} = Photos.log_event(photo, "processing_started", "system", nil)

      assert log.actor_id == nil
      assert log.actor_type == "system"
    end
  end

  describe "get_photo_history/1" do
    test "returns all events for a photo" do
      photo = photo_fixture()

      {:ok, _} = Photos.log_event(photo, "photo_uploaded", "user", nil)
      {:ok, _} = Photos.log_event(photo, "processing_started", "system", nil)
      {:ok, _} = Photos.log_event(photo, "nsfw_checked", "ai", nil, %{score: 0.1})

      history = Photos.get_photo_history(photo.id)
      event_types = Enum.map(history, & &1.event_type)

      assert length(history) == 3
      assert "photo_uploaded" in event_types
      assert "processing_started" in event_types
      assert "nsfw_checked" in event_types
    end

    test "returns empty list for photo with no events" do
      photo = photo_fixture()
      assert Photos.get_photo_history(photo.id) == []
    end

    test "preloads actor association" do
      user = user_fixture()
      photo = photo_fixture()

      {:ok, _} = Photos.log_event(photo, "appeal_created", "user", user.id)

      [event] = Photos.get_photo_history(photo.id)
      assert event.actor.id == user.id
    end
  end

  describe "list_recent_events/1" do
    test "returns most recent events" do
      photo1 = photo_fixture()
      photo2 = photo_fixture()

      {:ok, _} = Photos.log_event(photo1, "photo_uploaded", "user", nil)
      {:ok, _} = Photos.log_event(photo2, "photo_uploaded", "user", nil)

      events = Photos.list_recent_events(10)

      assert length(events) == 2
    end

    test "respects limit" do
      photo = photo_fixture()

      for i <- 1..5 do
        {:ok, _} = Photos.log_event(photo, "processing_started", "system", nil, %{iteration: i})
        Process.sleep(10)
      end

      events = Photos.list_recent_events(3)
      assert length(events) == 3
    end
  end

  describe "PhotoAuditLog schema" do
    test "create_changeset validates required fields" do
      changeset = PhotoAuditLog.create_changeset(%PhotoAuditLog{}, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors.photo_id
      assert "can't be blank" in errors.event_type
      assert "can't be blank" in errors.actor_type
    end

    test "create_changeset validates event_type" do
      changeset =
        PhotoAuditLog.create_changeset(%PhotoAuditLog{}, %{
          photo_id: Ecto.UUID.generate(),
          event_type: "invalid_event",
          actor_type: "system"
        })

      errors = errors_on(changeset)
      assert "is invalid" in errors.event_type
    end

    test "create_changeset validates actor_type" do
      changeset =
        PhotoAuditLog.create_changeset(%PhotoAuditLog{}, %{
          photo_id: Ecto.UUID.generate(),
          event_type: "photo_uploaded",
          actor_type: "invalid_actor"
        })

      errors = errors_on(changeset)
      assert "is invalid" in errors.actor_type
    end

    test "valid_event_types returns all event types" do
      types = PhotoAuditLog.valid_event_types()
      assert "photo_uploaded" in types
      assert "appeal_created" in types
      assert "blacklist_added" in types
    end

    test "valid_actor_types returns all actor types" do
      types = PhotoAuditLog.valid_actor_types()
      assert "system" in types
      assert "ai" in types
      assert "user" in types
      assert "moderator" in types
      assert "admin" in types
    end
  end
end
