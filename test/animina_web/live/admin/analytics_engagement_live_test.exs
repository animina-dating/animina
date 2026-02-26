defmodule AniminaWeb.Admin.AnalyticsEngagementLiveTest do
  use AniminaWeb.AdminCase

  describe "Analytics Engagement page" do
    setup :setup_admin

    test "requires admin access", %{conn: conn} do
      assert_requires_admin(conn, ~p"/admin/analytics/engagement")
    end

    test "renders engagement dashboard for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/analytics/engagement")

      assert html =~ "Engagement"
      assert html =~ "DAU"
      assert html =~ "Stickiness"
      assert html =~ "Feature Engagement"
    end
  end
end
