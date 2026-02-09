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
      assert {:error, {:redirect, _}} = live(conn, ~p"/users/settings/emails")
    end

    test "renders empty state", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/users/settings/emails")

      assert html =~ "Email History"
      assert html =~ "No emails found"
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
      {:ok, _view, html} = live(conn, ~p"/users/settings/emails")

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
      {:ok, view, html} = live(conn, ~p"/users/settings/emails")

      refute html =~ "Your confirmation PIN is 999888"

      html = view |> element(~s(tr[phx-value-id="#{log.id}"])) |> render_click()

      assert html =~ "Your confirmation PIN is 999888"
    end

    test "filters by type", %{conn: conn, user: user} do
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
      {:ok, view, _html} = live(conn, ~p"/users/settings/emails")

      html =
        view
        |> element("select[name=type]")
        |> render_change(%{"type" => "confirmation_pin"})

      assert html =~ "1 email"
    end
  end
end
