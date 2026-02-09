defmodule AniminaWeb.UserLive.EmailLogsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Emails

  describe "UserLive.EmailLogs" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "requires authentication", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/logs/emails")
    end

    test "renders empty state with breadcrumbs", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/logs/emails")

      assert html =~ "Email History"
      assert html =~ "No emails found"
      # Breadcrumb link to settings
      assert html =~ ~s(/settings)
      assert html =~ "Settings"
    end

    test "shows only current user's emails", %{conn: conn, user: user} do
      other_user = user_fixture()

      # Create a log for current user
      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: user.email,
        subject: "Your PIN",
        body: "PIN Body",
        status: "sent",
        user_id: user.id
      })

      # Create a log for another user
      Emails.create_email_log(%{
        email_type: "password_reset",
        recipient: other_user.email,
        subject: "Other Reset Subject",
        body: "Reset Body",
        status: "sent",
        user_id: other_user.id
      })

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/logs/emails")

      assert html =~ "1 email"
      assert html =~ "Your PIN"
      refute html =~ "Other Reset Subject"
    end

    test "expands row to show body", %{conn: conn, user: user} do
      {:ok, log} =
        Emails.create_email_log(%{
          email_type: "confirmation_pin",
          recipient: user.email,
          subject: "Your PIN",
          body: "Your confirmation PIN is 999888.",
          status: "sent",
          user_id: user.id
        })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/logs/emails")

      refute html =~ "Your confirmation PIN is 999888"

      html = view |> element(~s(tr[phx-value-id="#{log.id}"])) |> render_click()

      assert html =~ "Your confirmation PIN is 999888"
    end

    test "shows multiple emails", %{conn: conn, user: user} do
      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: user.email,
        subject: "PIN",
        body: "Body",
        status: "sent",
        user_id: user.id
      })

      Emails.create_email_log(%{
        email_type: "password_reset",
        recipient: user.email,
        subject: "Reset",
        body: "Body",
        status: "sent",
        user_id: user.id
      })

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/logs/emails")

      assert html =~ "2 emails"
    end

    test "filters by status", %{conn: conn, user: user} do
      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: user.email,
        subject: "Sent Email",
        body: "Body",
        status: "sent",
        user_id: user.id
      })

      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: user.email,
        subject: "Failed Email",
        body: "Body",
        status: "error",
        error_message: "SMTP error",
        user_id: user.id
      })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/logs/emails")

      # Both shown initially
      assert html =~ "Sent Email"
      assert html =~ "Failed Email"

      # Filter to only sent
      html =
        view
        |> element("select[name=status]")
        |> render_change(%{status: "sent"})

      assert html =~ "Sent Email"
      refute html =~ "Failed Email"
    end

    test "filters by type", %{conn: conn, user: user} do
      Emails.create_email_log(%{
        email_type: "confirmation_pin",
        recipient: user.email,
        subject: "PIN Email",
        body: "Body",
        status: "sent",
        user_id: user.id
      })

      Emails.create_email_log(%{
        email_type: "password_reset",
        recipient: user.email,
        subject: "Reset Email",
        body: "Body",
        status: "sent",
        user_id: user.id
      })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/logs/emails")

      assert html =~ "PIN Email"
      assert html =~ "Reset Email"

      # Filter to only password_reset
      html =
        view
        |> element("select[name=type]")
        |> render_change(%{type: "password_reset"})

      refute html =~ "PIN Email"
      assert html =~ "Reset Email"
    end

    test "shows per page selector", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/logs/emails")

      assert html =~ "Per page"
      assert html =~ "50"
      assert html =~ "100"
      assert html =~ "250"
      assert html =~ "500"
    end
  end
end
