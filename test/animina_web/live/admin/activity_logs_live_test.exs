defmodule AniminaWeb.Admin.ActivityLogsLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.ActivityLog

  describe "ActivityLogsLive" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/logs/activity")
    end

    test "renders empty state", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/logs/activity")

      assert html =~ "Activity Logs"
    end

    test "lists activity log entries", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      ActivityLog.log("auth", "login_email", "User Max logged in via email", actor_id: admin.id)

      {:ok, _view, html} = live(conn, ~p"/admin/logs/activity")

      assert html =~ "Activity Logs"
      assert html =~ "login_email"
      assert html =~ "User Max logged in via email"
    end

    test "filters by category", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      ActivityLog.log("auth", "login_email", "Login event")
      ActivityLog.log("social", "message_sent", "Message event")

      {:ok, view, _html} = live(conn, ~p"/admin/logs/activity")

      html =
        view
        |> element("select[name=category]")
        |> render_change(%{"category" => "auth"})

      assert html =~ "login_email"
      assert html =~ "1 entry"
    end

    test "filters by event", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      ActivityLog.log("auth", "login_email", "Email login")
      ActivityLog.log("auth", "login_passkey", "Passkey login")

      {:ok, view, _html} = live(conn, ~p"/admin/logs/activity")

      html =
        view
        |> element("select[name=event]")
        |> render_change(%{"event" => "login_email"})

      assert html =~ "1 entry"
    end

    test "per-page selector works", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, view, html} = live(conn, ~p"/admin/logs/activity")

      # Default per_page buttons should be visible
      assert html =~ "50"
      assert html =~ "100"
      assert html =~ "250"
      assert html =~ "500"

      # Click a per-page button
      view
      |> element("button[phx-value-per_page=\"100\"]")
      |> render_click()

      assert_patched(view, "/admin/logs/activity?page=1&per_page=100&sort_dir=desc")
    end
  end

  describe "LogsIndexLive activity card" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "shows Activity Logs card", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/logs")

      assert html =~ "Activity Logs"
      assert html =~ "Unified activity log"
    end
  end
end
