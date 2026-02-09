defmodule AniminaWeb.LegacyRedirectControllerTest do
  use AniminaWeb.ConnCase, async: true

  describe "settings redirects" do
    test "GET /users/settings redirects to /settings", %{conn: conn} do
      conn = get(conn, "/users/settings")
      assert redirected_to(conn, 301) == "/settings"
    end

    test "GET /users/settings/account redirects to /settings/account", %{conn: conn} do
      conn = get(conn, "/users/settings/account")
      assert redirected_to(conn, 301) == "/settings/account"
    end

    test "GET /users/settings/traits?step=green preserves query string", %{conn: conn} do
      conn = get(conn, "/users/settings/traits?step=green")
      assert redirected_to(conn, 301) == "/settings/traits?step=green"
    end

    test "GET /users/settings/deeply/nested redirects correctly", %{conn: conn} do
      conn = get(conn, "/users/settings/deeply/nested")
      assert redirected_to(conn, 301) == "/settings/deeply/nested"
    end
  end

  describe "moodboard redirects" do
    test "GET /moodboard/:user_id redirects to /users/:user_id", %{conn: conn} do
      uuid = Ecto.UUID.generate()
      conn = get(conn, "/moodboard/#{uuid}")
      assert redirected_to(conn, 301) == "/users/#{uuid}"
    end
  end
end
