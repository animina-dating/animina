defmodule AniminaWeb.Admin.AdminHubTest do
  use AniminaWeb.AdminCase

  describe "Admin Hub page" do
    setup :setup_admin

    test "requires admin access", %{conn: conn} do
      assert_requires_admin(conn, ~p"/admin")
    end

    test "renders hub cards for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin")

      assert html =~ "Administration"
      assert html =~ "Photo Reviews"
      assert html =~ "Photo Blacklist"
      assert html =~ "Manage Roles"
      assert html =~ "Feature Flags"
      assert html =~ "Analytics"
      assert html =~ "Logs"
    end

    test "has page title", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin")

      assert page_title(lv) == "Admin · ANIMINA"
    end

    test "navigation links are present", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin")

      assert has_element?(lv, "main a[href='/admin/photo-reviews']")
      assert has_element?(lv, "main a[href='/admin/photo-blacklist']")
      assert has_element?(lv, "main a[href='/admin/roles']")
      assert has_element?(lv, "main a[href='/admin/flags']")
      assert has_element?(lv, "main a[href='/admin/analytics']")
      assert has_element?(lv, "main a[href='/admin/logs']")
    end
  end
end
