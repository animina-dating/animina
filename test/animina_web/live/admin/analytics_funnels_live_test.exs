defmodule AniminaWeb.Admin.AnalyticsFunnelsLiveTest do
  use AniminaWeb.AdminCase

  describe "Analytics Funnels page" do
    setup :setup_admin

    test "requires admin access", %{conn: conn} do
      assert_requires_admin(conn, ~p"/admin/analytics/funnels")
    end

    test "renders funnel for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/analytics/funnels")

      assert html =~ "Conversion Funnel"
      assert html =~ "Visitors"
      assert html =~ "Registered"
      assert html =~ "Mutual Match"
    end
  end
end
