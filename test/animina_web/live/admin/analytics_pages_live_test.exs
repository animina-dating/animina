defmodule AniminaWeb.Admin.AnalyticsPagesLiveTest do
  use AniminaWeb.AdminCase

  describe "Analytics Pages page" do
    setup :setup_admin

    test "requires admin access", %{conn: conn} do
      assert_requires_admin(conn, ~p"/admin/analytics/pages")
    end

    test "renders page view breakdown for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/analytics/pages")

      assert html =~ "Page Views by Path"
    end

    test "supports date range parameter", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin/analytics/pages?days=7")

      assert has_element?(lv, "a.btn-primary", "7 days")
    end
  end
end
