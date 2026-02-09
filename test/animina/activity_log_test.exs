defmodule Animina.ActivityLogTest do
  use Animina.DataCase, async: true

  alias Animina.ActivityLog
  alias Animina.ActivityLog.ActivityLogEntry

  import Animina.AccountsFixtures

  describe "ActivityLogEntry changeset" do
    test "valid changeset with all fields" do
      changeset =
        ActivityLogEntry.changeset(%ActivityLogEntry{}, %{
          category: "auth",
          event: "login_email",
          summary: "User logged in via email"
        })

      assert changeset.valid?
    end

    test "valid changeset with optional fields" do
      user = user_fixture()

      changeset =
        ActivityLogEntry.changeset(%ActivityLogEntry{}, %{
          category: "admin",
          event: "role_granted",
          summary: "Admin granted moderator role",
          actor_id: user.id,
          subject_id: user.id,
          metadata: %{role: "moderator"}
        })

      assert changeset.valid?
    end

    test "invalid with missing required fields" do
      changeset = ActivityLogEntry.changeset(%ActivityLogEntry{}, %{})
      refute changeset.valid?
      assert %{category: _, event: _, summary: _} = errors_on(changeset)
    end

    test "invalid with unknown category" do
      changeset =
        ActivityLogEntry.changeset(%ActivityLogEntry{}, %{
          category: "unknown",
          event: "login_email",
          summary: "test"
        })

      refute changeset.valid?
      assert %{category: _} = errors_on(changeset)
    end

    test "invalid with unknown event" do
      changeset =
        ActivityLogEntry.changeset(%ActivityLogEntry{}, %{
          category: "auth",
          event: "unknown_event",
          summary: "test"
        })

      refute changeset.valid?
      assert %{event: _} = errors_on(changeset)
    end

    test "automatically sets inserted_at" do
      changeset =
        ActivityLogEntry.changeset(%ActivityLogEntry{}, %{
          category: "auth",
          event: "login_email",
          summary: "test"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :inserted_at) != nil
    end
  end

  describe "ActivityLogEntry.valid_categories/0" do
    test "returns all categories" do
      categories = ActivityLogEntry.valid_categories()
      assert "auth" in categories
      assert "social" in categories
      assert "profile" in categories
      assert "admin" in categories
      assert "system" in categories
    end
  end

  describe "ActivityLogEntry.events_for_category/1" do
    test "returns events for auth category" do
      events = ActivityLogEntry.events_for_category("auth")
      assert "login_email" in events
      assert "logout" in events
    end

    test "returns empty list for unknown category" do
      assert ActivityLogEntry.events_for_category("unknown") == []
    end
  end

  describe "log/4" do
    test "creates an entry and returns it preloaded" do
      user = user_fixture()

      {:ok, entry} =
        ActivityLog.log("auth", "login_email", "User logged in via email", actor_id: user.id)

      assert entry.category == "auth"
      assert entry.event == "login_email"
      assert entry.summary == "User logged in via email"
      assert entry.actor_id == user.id
      assert entry.actor != nil
      assert entry.actor.id == user.id
    end

    test "creates an entry with metadata" do
      {:ok, entry} =
        ActivityLog.log("system", "email_sent", "System sent confirmation email",
          metadata: %{"email_type" => "confirmation_pin", "recipient" => "test@example.com"}
        )

      assert entry.metadata["email_type"] == "confirmation_pin"
    end

    test "creates an entry with actor and subject" do
      actor = user_fixture()
      subject = user_fixture()

      {:ok, entry} =
        ActivityLog.log("admin", "role_granted", "Admin granted moderator role",
          actor_id: actor.id,
          subject_id: subject.id
        )

      assert entry.actor_id == actor.id
      assert entry.subject_id == subject.id
    end

    test "broadcasts via PubSub" do
      Phoenix.PubSub.subscribe(Animina.PubSub, ActivityLog.pubsub_topic())

      {:ok, entry} =
        ActivityLog.log("auth", "login_email", "User logged in")

      assert_receive {:new_activity_log, ^entry}
    end

    test "returns error for invalid data" do
      {:error, changeset} = ActivityLog.log("invalid", "invalid", "test")
      refute changeset.valid?
    end
  end

  describe "list_activity_logs/1" do
    test "returns paginated results" do
      for i <- 1..5 do
        ActivityLog.log("auth", "login_email", "Login #{i}")
      end

      result = ActivityLog.list_activity_logs(page: 1, per_page: 3)
      assert length(result.entries) == 3
      assert result.total_count == 5
      assert result.total_pages == 2
    end

    test "filters by category" do
      ActivityLog.log("auth", "login_email", "Login")
      ActivityLog.log("social", "message_sent", "Message")

      result = ActivityLog.list_activity_logs(filter_category: "auth")
      assert length(result.entries) == 1
      assert hd(result.entries).category == "auth"
    end

    test "filters by event" do
      ActivityLog.log("auth", "login_email", "Email login")
      ActivityLog.log("auth", "login_passkey", "Passkey login")

      result = ActivityLog.list_activity_logs(filter_event: "login_email")
      assert length(result.entries) == 1
      assert hd(result.entries).event == "login_email"
    end

    test "filters by user_id matching actor or subject" do
      user = user_fixture()
      other = user_fixture()

      # Count entries already created by user_fixture (account_registered events)
      baseline = ActivityLog.list_activity_logs(filter_user_id: user.id).total_count

      ActivityLog.log("auth", "login_email", "Login", actor_id: user.id)

      ActivityLog.log("admin", "role_granted", "Role granted",
        actor_id: other.id,
        subject_id: user.id
      )

      ActivityLog.log("auth", "login_email", "Other login", actor_id: other.id)

      result = ActivityLog.list_activity_logs(filter_user_id: user.id)
      assert length(result.entries) == baseline + 2
    end

    test "sorts descending by default" do
      {:ok, _} = ActivityLog.log("auth", "login_email", "First")
      Process.sleep(1100)
      {:ok, _} = ActivityLog.log("auth", "login_email", "Second")

      result = ActivityLog.list_activity_logs()
      summaries = Enum.map(result.entries, & &1.summary)
      assert hd(summaries) == "Second"
    end

    test "sorts ascending when requested" do
      {:ok, _} = ActivityLog.log("auth", "login_email", "First")
      Process.sleep(1100)
      {:ok, _} = ActivityLog.log("auth", "login_email", "Second")

      result = ActivityLog.list_activity_logs(sort_dir: :asc)
      summaries = Enum.map(result.entries, & &1.summary)
      assert hd(summaries) == "First"
    end
  end

  describe "count/0" do
    test "returns the total count" do
      assert ActivityLog.count() == 0

      ActivityLog.log("auth", "login_email", "Login")
      assert ActivityLog.count() == 1
    end
  end
end
