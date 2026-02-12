defmodule AniminaWeb.Admin.EmailLogsLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Emails

  describe "EmailLogsLive" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/logs/emails")
    end

    test "renders empty state", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/logs/emails")

      assert html =~ "Email Logs"
    end

    test "lists email log entries", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, _} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: "user@example.com",
          subject: "Your PIN",
          body: "PIN is 123456",
          status: "sent",
          user_id: admin.id
        })

      {:ok, _view, html} = live(conn, ~p"/admin/logs/emails")

      assert html =~ "Email Logs"
      assert html =~ "confirmation_pin"
      assert html =~ "user@example.com"
      assert html =~ "Your PIN"
      assert html =~ "1 entry"
    end

    test "filters by email type", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: "a@example.com",
        subject: "PIN",
        body: "Body",
        status: "sent"
      })

      Emails.create_email_log(%{
        email_type: "password_reset",
        recipient: "b@example.com",
        subject: "Reset",
        body: "Body",
        status: "sent"
      })

      {:ok, view, _html} = live(conn, ~p"/admin/logs/emails")

      # Filter by type
      html =
        view
        |> element("select[name=type]")
        |> render_change(%{"type" => "confirmation_pin"})

      assert html =~ "confirmation_pin"
      assert html =~ "1 entry"
    end

    test "filters by status", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: "a@example.com",
        subject: "PIN",
        body: "Body",
        status: "sent"
      })

      Emails.create_email_log(%{
        email_type: "password_reset",
        recipient: "b@example.com",
        subject: "Reset",
        body: "Body",
        status: "error",
        error_message: "Connection refused"
      })

      {:ok, view, _html} = live(conn, ~p"/admin/logs/emails")

      html =
        view
        |> element("select[name=status]")
        |> render_change(%{"status" => "error"})

      assert html =~ "1 entry"
      assert html =~ "Connection refused"
    end

    test "expands row to show body", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, log} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: "user@example.com",
          subject: "Your PIN",
          body: "Your confirmation PIN is 123456. It expires in 30 minutes.",
          status: "sent"
        })

      {:ok, view, html} = live(conn, ~p"/admin/logs/emails")

      # Body should not be visible initially
      refute html =~ "Your confirmation PIN is 123456"

      # Click to expand
      html = view |> element(~s(tr[phx-value-id="#{log.id}"])) |> render_click()

      assert html =~ "Your confirmation PIN is 123456"
    end
  end

  describe "LogsIndexLive" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/logs")
    end

    test "renders log index with cards", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/logs")

      assert html =~ "Logs"
      assert html =~ "Email Logs"
      assert html =~ "AI Jobs"
    end
  end
end
