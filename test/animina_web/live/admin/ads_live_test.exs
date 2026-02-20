defmodule AniminaWeb.Admin.AdsLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AdsFixtures
  import Phoenix.LiveViewTest

  describe "GET /admin/ads" do
    test "requires admin access", %{conn: conn} do
      conn = get(conn, "/admin/ads")
      assert redirected_to(conn) =~ "/"
    end

    test "renders ad list for admin", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()
      ad = ad_fixture(%{description: "Test campaign"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/ads")

      assert html =~ "Ad Campaigns"
      assert html =~ "Test campaign"
      assert html =~ to_string(ad.number)
    end

    test "shows empty state when no ads", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/ads")

      assert html =~ "No ads created yet"
    end
  end
end
