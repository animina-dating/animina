defmodule AniminaWeb.AdQrControllerTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AdsFixtures

  describe "GET /admin/ads/:id/qr-code (download)" do
    test "requires admin authentication", %{conn: conn} do
      ad = ad_fixture()
      conn = get(conn, "/admin/ads/#{ad.id}/qr-code")
      assert redirected_to(conn) =~ "/"
    end

    test "returns 404 when ad has no QR code", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()
      ad = ad_fixture()

      conn =
        conn
        |> log_in_user(admin)
        |> get("/admin/ads/#{ad.id}/qr-code")

      assert conn.status == 404
    end
  end

  describe "GET /admin/ads/:id/qr-code/show (inline)" do
    test "requires admin authentication", %{conn: conn} do
      ad = ad_fixture()
      conn = get(conn, "/admin/ads/#{ad.id}/qr-code/show")
      assert redirected_to(conn) =~ "/"
    end

    test "returns 404 for non-existent ad", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()

      conn =
        conn
        |> log_in_user(admin)
        |> get("/admin/ads/#{Ecto.UUID.generate()}/qr-code")

      assert conn.status == 404
    end
  end
end
