defmodule AniminaWeb.UserLive.LoginHistoryTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.ActivityLog

  describe "UserLive.LoginHistory" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "requires authentication", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/my/logs/logins")
    end

    test "renders breadcrumbs and empty state", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/my/logs/logins")

      assert html =~ "Login History"
      assert html =~ "No login events found"
      # Breadcrumb links
      assert html =~ ~s(/my)
      assert html =~ "Logs"
    end

    test "shows only current user's events", %{conn: conn, user: user} do
      other_user = user_fixture(%{display_name: "Other Person"})

      ActivityLog.log("auth", "login_email", "#{user.display_name} logged in via email",
        actor_id: user.id,
        metadata: %{"user_agent" => "Mozilla/5.0 Chrome", "ip_address" => "127.0.0.1"}
      )

      ActivityLog.log(
        "auth",
        "login_email",
        "Other Person logged in via email",
        actor_id: other_user.id,
        metadata: %{"user_agent" => "Mozilla/5.0 Firefox", "ip_address" => "10.0.0.1"}
      )

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/my/logs/logins")

      assert html =~ "1 event"
      assert html =~ "#{user.display_name} logged in via email"
      refute html =~ "Other Person logged in via email"
    end

    test "displays login, logout, and failed events", %{conn: conn, user: user} do
      ActivityLog.log("auth", "login_email", "#{user.display_name} logged in via email",
        actor_id: user.id,
        metadata: %{"user_agent" => "Mozilla/5.0 Chrome", "ip_address" => "127.0.0.1"}
      )

      ActivityLog.log("auth", "logout", "#{user.display_name} logged out",
        actor_id: user.id,
        metadata: %{"user_agent" => "Mozilla/5.0 Chrome", "ip_address" => "127.0.0.1"}
      )

      ActivityLog.log("auth", "login_failed", "Failed login attempt for test@example.com",
        actor_id: user.id,
        metadata: %{
          "email" => "test@example.com",
          "user_agent" => "Mozilla/5.0 Chrome",
          "ip_address" => "127.0.0.1"
        }
      )

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/my/logs/logins")

      assert html =~ "3 events"
      assert html =~ "login_email"
      assert html =~ "logout"
      assert html =~ "login_failed"
    end

    test "filters by event type", %{conn: conn, user: user} do
      ActivityLog.log("auth", "login_email", "#{user.display_name} logged in via email",
        actor_id: user.id
      )

      ActivityLog.log("auth", "logout", "#{user.display_name} logged out", actor_id: user.id)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/my/logs/logins")

      # Both visible initially
      assert html =~ "Email Login"
      assert html =~ "logged out"

      # Filter to only login_email
      html =
        view
        |> element("select[name=event]")
        |> render_change(%{event: "login_email"})

      assert html =~ "Email Login"
      refute html =~ "logged out"
    end

    test "renders heatmap SVG", %{conn: conn, user: user} do
      ActivityLog.log("auth", "login_email", "#{user.display_name} logged in via email",
        actor_id: user.id
      )

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/my/logs/logins")

      assert html =~ "<svg"
      assert html =~ "Login Activity"
    end

    test "shows device info from metadata", %{conn: conn, user: user} do
      ActivityLog.log("auth", "login_email", "#{user.display_name} logged in via email",
        actor_id: user.id,
        metadata: %{
          "user_agent" =>
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0.0.0",
          "ip_address" => "192.168.1.1"
        }
      )

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/my/logs/logins")

      assert html =~ "Chrome"
      assert html =~ "macOS"
    end

    test "shows per page selector", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/my/logs/logins")

      assert html =~ "Per page"
    end
  end
end
