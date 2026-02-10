defmodule AniminaWeb.Admin.AdminHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Admin Hub page" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end

    test "renders hub cards for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin")

      assert html =~ "Administration"
      assert html =~ "Photo Reviews"
      assert html =~ "Photo Blacklist"
      assert html =~ "Manage Roles"
      assert html =~ "Feature Flags"
      assert html =~ "Logs"
    end

    test "has page title", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin")

      assert page_title(lv) == "Administration - ANIMINA"
    end

    test "navigation links are present", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin")

      assert has_element?(lv, "main a[href='/admin/photo-reviews']")
      assert has_element?(lv, "main a[href='/admin/photo-blacklist']")
      assert has_element?(lv, "main a[href='/admin/roles']")
      assert has_element?(lv, "main a[href='/admin/flags']")
      assert has_element?(lv, "main a[href='/admin/logs']")
    end
  end
end
