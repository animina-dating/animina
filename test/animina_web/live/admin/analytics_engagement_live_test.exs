defmodule AniminaWeb.Admin.AnalyticsEngagementLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Analytics Engagement page" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/analytics/engagement")
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
