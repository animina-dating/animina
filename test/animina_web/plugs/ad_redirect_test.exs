defmodule AniminaWeb.Plugs.AdRedirectTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AdsFixtures

  alias Animina.Ads

  describe "AdRedirect plug" do
    test "redirects to / when valid ad code is provided", %{conn: conn} do
      ad = ad_fixture()
      code = Integer.to_string(ad.number, 36) |> String.downcase()

      conn = get(conn, "/?ad=#{code}")

      assert redirected_to(conn) == "/"
      assert conn.halted
    end

    test "logs a visit for active ad", %{conn: conn} do
      ad = ad_fixture()
      code = Integer.to_string(ad.number, 36) |> String.downcase()

      conn
      |> put_req_header("user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")
      |> put_req_header("accept-language", "de-DE,de;q=0.9")
      |> get("/?ad=#{code}")

      assert Ads.count_visits(ad.id, exclude_bots: false) == 1
    end

    test "sets ad source cookie", %{conn: conn} do
      ad = ad_fixture()
      code = Integer.to_string(ad.number, 36) |> String.downcase()

      conn = get(conn, "/?ad=#{code}")

      assert conn.resp_cookies["_animina_ad_source"]
    end

    test "redirects to / for non-existent ad number", %{conn: conn} do
      conn = get(conn, "/?ad=zzz")

      assert redirected_to(conn) == "/"
      assert conn.halted
    end

    test "passes through for invalid code value", %{conn: conn} do
      conn = get(conn, "/?ad=!@#")

      # Should not redirect — passes through to normal IndexLive
      refute conn.halted
    end

    test "does not log visit for inactive ad", %{conn: conn} do
      ad = ad_fixture(%{starts_on: ~D[2020-01-01], ends_on: ~D[2020-01-31]})
      code = Integer.to_string(ad.number, 36) |> String.downcase()

      get(conn, "/?ad=#{code}")

      assert Ads.count_visits(ad.id, exclude_bots: false) == 0
    end

    test "does not interfere with normal homepage requests", %{conn: conn} do
      conn = get(conn, "/")
      refute conn.halted
    end
  end
end
