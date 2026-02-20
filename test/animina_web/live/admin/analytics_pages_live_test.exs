defmodule AniminaWeb.Admin.AnalyticsPagesLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Analytics Pages page" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/analytics/pages")
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
