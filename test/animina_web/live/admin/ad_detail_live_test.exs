defmodule AniminaWeb.Admin.AdDetailLiveTest do
  use AniminaWeb.ConnCase, async: true

  alias Animina.Ads.QrCode

  import Animina.AdsFixtures
  import Phoenix.LiveViewTest

  describe "GET /admin/ads/:id" do
    test "requires admin access", %{conn: conn} do
      ad = ad_fixture()
      conn = get(conn, "/admin/ads/#{ad.id}")
      assert redirected_to(conn) =~ "/"
    end

    test "renders ad detail for admin", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()
      ad = ad_fixture(%{description: "Detail test"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/ads/#{ad.id}")

      assert html =~ "Ad ##{ad.number}"
      assert html =~ "Detail test"
      assert html =~ ad.url
    end

    test "shows visit and conversion stats", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()
      ad = ad_fixture()
      ad_visit_fixture(ad)
      ad_visit_fixture(ad)

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/ads/#{ad.id}")

      # Should show visit count of 2
      assert html =~ "Visits"
      assert html =~ "Conversions"
    end

    test "redirects for non-existent ad", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()

      {:error, {:live_redirect, %{to: "/admin/ads"}}} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/ads/#{Ecto.UUID.generate()}")
    end
  end

  describe "generate-qr" do
    test "shows Generate QR button when qr_code_path is nil", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()
      ad = ad_fixture()

      # Ad fixture doesn't generate QR, so qr_code_path is nil
      {:ok, _lv, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/ads/#{ad.id}")

      assert html =~ "Generate QR"
    end

    test "generate-qr event attempts QR generation", %{conn: conn} do
      admin = Animina.AccountsFixtures.admin_fixture()
      ad = ad_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/ads/#{ad.id}")

      html = lv |> element("button", "Generate QR") |> render_click()

      case QrCode.check_dependencies() do
        :ok ->
          # Tools available — QR generated, button replaced by image
          assert html =~ "QR code generated"
          assert html =~ "Download QR"
          refute html =~ "Generate QR"

        {:error, _reason} ->
          # Tools missing — error flash shown
          assert html =~ "not installed"
      end
    end
  end
end
