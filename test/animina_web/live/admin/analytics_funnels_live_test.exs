defmodule AniminaWeb.Admin.AnalyticsFunnelsLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Analytics Funnels page" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/analytics/funnels")
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
