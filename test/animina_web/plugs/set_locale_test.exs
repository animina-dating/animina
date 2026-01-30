defmodule AniminaWeb.Plugs.SetLocaleTest do
  use AniminaWeb.ConnCase, async: true

  alias AniminaWeb.Plugs.SetLocale

  import Animina.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, AniminaWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn}
  end

  describe "supported_locales/0" do
    test "returns all 8 supported locales" do
      locales = SetLocale.supported_locales()
      assert length(locales) == 8
      assert "de" in locales
      assert "en" in locales
      assert "ar" in locales
    end
  end

  describe "call/2 — Accept-Language header parsing" do
    test "detects English from Accept-Language header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "en-US,en;q=0.9")
        |> SetLocale.call([])

      assert conn.assigns[:locale] == "en"
      assert get_session(conn, :locale) == "en"
    end

    test "detects German from Accept-Language header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "de-DE,de;q=0.9,en;q=0.8")
        |> SetLocale.call([])

      assert conn.assigns[:locale] == "de"
    end

    test "picks highest quality supported language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "ja;q=0.9,fr;q=0.8,en;q=0.7")
        |> SetLocale.call([])

      # ja is not supported, so fr (next highest) is chosen
      assert conn.assigns[:locale] == "fr"
    end

    test "falls back to default when no supported language in header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "ja,zh;q=0.9")
        |> SetLocale.call([])

      assert conn.assigns[:locale] == "en"
    end

    test "falls back to default when no Accept-Language header", %{conn: conn} do
      conn = SetLocale.call(conn, [])

      assert conn.assigns[:locale] == "en"
    end
  end

  describe "call/2 — session persistence" do
    test "session locale takes priority over Accept-Language", %{conn: conn} do
      conn =
        conn
        |> put_session(:locale, "fr")
        |> put_req_header("accept-language", "en-US")
        |> SetLocale.call([])

      assert conn.assigns[:locale] == "fr"
    end

    test "stores locale in session", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "es")
        |> SetLocale.call([])

      assert get_session(conn, :locale) == "es"
    end
  end

  describe "call/2 — user preference" do
    setup %{conn: conn} do
      user = user_fixture(%{language: "tr"})
      scope = Animina.Accounts.Scope.for_user(user)

      conn =
        conn
        |> assign(:current_scope, scope)

      %{conn: conn, user: user}
    end

    test "user's DB language takes highest priority", %{conn: conn} do
      conn =
        conn
        |> put_session(:locale, "en")
        |> put_req_header("accept-language", "fr")
        |> SetLocale.call([])

      assert conn.assigns[:locale] == "tr"
    end
  end

  describe "call/2 — unsupported locale handling" do
    test "rejects unsupported locale and falls back to default", %{conn: conn} do
      conn =
        conn
        |> put_session(:locale, "xx")
        |> SetLocale.call([])

      assert conn.assigns[:locale] == "en"
    end
  end
end
