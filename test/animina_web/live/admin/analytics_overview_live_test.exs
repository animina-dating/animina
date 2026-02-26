defmodule AniminaWeb.Admin.AnalyticsOverviewLiveTest do
  use AniminaWeb.AdminCase

  describe "Analytics Overview page" do
    setup :setup_admin

    test "requires admin access", %{conn: conn} do
      assert_requires_admin(conn, ~p"/admin/analytics")
    end

    test "renders overview for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/analytics")

      assert html =~ "Analytics"
      assert html =~ "Page Views"
      assert html =~ "Sessions"
      assert html =~ "DAU"
      assert html =~ "WAU"
      assert html =~ "MAU"
    end

    test "has sub-page navigation cards", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin/analytics")

      assert has_element?(lv, "a[href='/admin/analytics/pages']")
      assert has_element?(lv, "a[href='/admin/analytics/funnels']")
      assert has_element?(lv, "a[href='/admin/analytics/engagement']")
    end
  end
end
