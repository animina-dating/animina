defmodule Animina.Emails.EmailLogTest do
  use Animina.DataCase, async: true

  alias Animina.Emails
  alias Animina.Emails.EmailLog

  import Animina.AccountsFixtures

  describe "create_email_log/1" do
    test "creates a log entry with valid attrs" do
      user = user_fixture()

      attrs = %{
        email_type: "confirmation_pin",
        recipient: user.email,
        subject: "Your PIN",
        body: "Your PIN is 123456",
        status: "sent",
        user_id: user.id
      }

      assert {:ok, %EmailLog{} = log} = Emails.create_email_log(attrs)
      assert log.email_type == "confirmation_pin"
      assert log.recipient == user.email
      assert log.subject == "Your PIN"
      assert log.body == "Your PIN is 123456"
      assert log.status == "sent"
      assert log.user_id == user.id
      assert log.error_message == nil
    end

    test "creates an error log entry" do
      attrs = %{
        email_type: "password_reset",
        recipient: "test@example.com",
        subject: "Reset",
        body: "Reset body",
        status: "error",
        error_message: "Connection refused"
      }

      assert {:ok, %EmailLog{} = log} = Emails.create_email_log(attrs)
      assert log.status == "error"
      assert log.error_message == "Connection refused"
      assert log.user_id == nil
    end

    test "rejects invalid status" do
      attrs = %{
        email_type: "confirmation_pin",
        recipient: "test@example.com",
        subject: "Test",
        body: "Body",
        status: "pending"
      }

      assert {:error, changeset} = Emails.create_email_log(attrs)
      assert errors_on(changeset).status
    end

    test "rejects invalid email_type" do
      attrs = %{
        email_type: "unknown_type",
        recipient: "test@example.com",
        subject: "Test",
        body: "Body",
        status: "sent"
      }

      assert {:error, changeset} = Emails.create_email_log(attrs)
      assert errors_on(changeset).email_type
    end

    test "requires required fields" do
      assert {:error, changeset} = Emails.create_email_log(%{})
      assert errors_on(changeset).email_type
      assert errors_on(changeset).recipient
      assert errors_on(changeset).subject
      assert errors_on(changeset).body
      assert errors_on(changeset).status
    end
  end

  describe "deliver_and_log/2" do
    test "logs a successful delivery" do
      email =
        Swoosh.Email.new()
        |> Swoosh.Email.to({"Test User", "test@example.com"})
        |> Swoosh.Email.from({"Sender", "sender@example.com"})
        |> Swoosh.Email.subject("Test Subject")
        |> Swoosh.Email.text_body("Test body content")

      assert {:ok, returned_email} =
               Emails.deliver_and_log(email,
                 email_type: :confirmation_pin,
                 user_id: nil
               )

      assert returned_email == email

      # Verify log was created
      result = Emails.list_email_logs()
      assert result.total_count == 1
      [log] = result.entries
      assert log.email_type == "confirmation_pin"
      assert log.recipient == "Test User <test@example.com>"
      assert log.subject == "Test Subject"
      assert log.body == "Test body content"
      assert log.status == "sent"
    end

    test "logs delivery with user_id" do
      user = user_fixture()

      email =
        Swoosh.Email.new()
        |> Swoosh.Email.to({"Test", user.email})
        |> Swoosh.Email.from({"Sender", "sender@example.com"})
        |> Swoosh.Email.subject("PIN")
        |> Swoosh.Email.text_body("Your PIN")

      assert {:ok, _} =
               Emails.deliver_and_log(email,
                 email_type: :confirmation_pin,
                 user_id: user.id
               )

      assert Emails.count_email_logs_for_user(user.id) == 1
    end
  end

  describe "list_email_logs/1" do
    setup do
      user = user_fixture()

      {:ok, log1} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: user.email,
          subject: "PIN 1",
          body: "Body 1",
          status: "sent",
          user_id: user.id
        })

      {:ok, log2} =
        Emails.create_email_log(%{
          email_type: "password_reset",
          recipient: user.email,
          subject: "Reset",
          body: "Body 2",
          status: "error",
          error_message: "Failed",
          user_id: user.id
        })

      {:ok, log3} =
        Emails.create_email_log(%{
          email_type: "daily_report",
          recipient: "admin@example.com",
          subject: "Report",
          body: "Body 3",
          status: "sent"
        })

      %{user: user, log1: log1, log2: log2, log3: log3}
    end

    test "returns all logs with defaults", %{log1: _, log2: _, log3: _} do
      result = Emails.list_email_logs()
      assert result.total_count == 3
      assert length(result.entries) == 3
    end

    test "filters by email_type", %{log1: _} do
      result = Emails.list_email_logs(filter_type: "confirmation_pin")
      assert result.total_count == 1
      [log] = result.entries
      assert log.email_type == "confirmation_pin"
    end

    test "filters by status" do
      result = Emails.list_email_logs(filter_status: "error")
      assert result.total_count == 1
      [log] = result.entries
      assert log.status == "error"
    end

    test "filters by user_id", %{user: user} do
      result = Emails.list_email_logs(user_id: user.id)
      assert result.total_count == 2
    end

    test "paginates results" do
      result = Emails.list_email_logs(per_page: 2, page: 1)
      assert length(result.entries) == 2
      assert result.total_pages == 2

      result2 = Emails.list_email_logs(per_page: 2, page: 2)
      assert length(result2.entries) == 1
    end

    test "sorts by column", %{log1: _, log2: _, log3: _} do
      result = Emails.list_email_logs(sort_by: :email_type, sort_dir: :asc)
      types = Enum.map(result.entries, & &1.email_type)
      assert types == ["confirmation_pin", "daily_report", "password_reset"]
    end
  end

  describe "distinct_email_types/0" do
    test "returns unique types" do
      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: "a@example.com",
        subject: "S",
        body: "B",
        status: "sent"
      })

      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: "b@example.com",
        subject: "S",
        body: "B",
        status: "sent"
      })

      Emails.create_email_log(%{
        email_type: "password_reset",
        recipient: "c@example.com",
        subject: "S",
        body: "B",
        status: "sent"
      })

      types = Emails.distinct_email_types()
      assert types == ["confirmation_pin", "password_reset"]
    end
  end

  describe "bounced status" do
    test "bounced is a valid status" do
      attrs = %{
        email_type: "confirmation_pin",
        recipient: "test@example.com",
        subject: "Test",
        body: "Body",
        status: "bounced",
        error_message: "550 unrouteable mail domain"
      }

      assert {:ok, %EmailLog{} = log} = Emails.create_email_log(attrs)
      assert log.status == "bounced"
      assert log.error_message == "550 unrouteable mail domain"
    end
  end

  describe "mark_as_bounced/2" do
    test "updates most recent sent entry to bounced" do
      user = user_fixture()

      {:ok, _log} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: user.email,
          subject: "Your PIN",
          body: "PIN: 123456",
          status: "sent",
          user_id: user.id
        })

      assert {:ok, updated} = Emails.mark_as_bounced(user.email, "550 no such user")
      assert updated.status == "bounced"
      assert updated.error_message == "550 no such user"
    end

    test "matches Name <email> format recipients" do
      {:ok, _log} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: "Test User <test@example.com>",
          subject: "Your PIN",
          body: "PIN: 123456",
          status: "sent"
        })

      assert {:ok, updated} = Emails.mark_as_bounced("test@example.com", "550 bounce")
      assert updated.status == "bounced"
    end

    test "returns {:error, :not_found} when no match" do
      assert {:error, :not_found} =
               Emails.mark_as_bounced("nonexistent@example.com", "550 bounce")
    end

    test "only updates sent entries, not error entries" do
      {:ok, _log} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: "test@example.com",
          subject: "Your PIN",
          body: "PIN: 123456",
          status: "error",
          error_message: "Connection refused"
        })

      assert {:error, :not_found} = Emails.mark_as_bounced("test@example.com", "550 bounce")
    end

    test "case-insensitive email matching" do
      {:ok, _log} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: "User@Example.COM",
          subject: "Your PIN",
          body: "PIN: 123456",
          status: "sent"
        })

      assert {:ok, updated} = Emails.mark_as_bounced("user@example.com", "550 bounce")
      assert updated.status == "bounced"
    end
  end

  describe "count_email_logs_for_user/1" do
    test "returns count for specific user" do
      user = user_fixture()

      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: user.email,
        subject: "S",
        body: "B",
        status: "sent",
        user_id: user.id
      })

      Emails.create_email_log(%{
        email_type: "daily_report",
        recipient: "admin@example.com",
        subject: "S",
        body: "B",
        status: "sent"
      })

      assert Emails.count_email_logs_for_user(user.id) == 1
    end
  end
end
