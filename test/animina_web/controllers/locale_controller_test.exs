defmodule AniminaWeb.LocaleControllerTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AccountsFixtures

  describe "POST /locale" do
    test "sets locale in session for valid locale", %{conn: conn} do
      conn = post(conn, ~p"/locale", %{"locale" => "fr"})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :locale) == "fr"
    end

    test "redirects back to referer", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://localhost:4000/users/settings")
        |> post(~p"/locale", %{"locale" => "en"})

      assert redirected_to(conn) == "/users/settings"
    end

    test "ignores invalid locale and redirects", %{conn: conn} do
      conn = post(conn, ~p"/locale", %{"locale" => "xx"})

      assert redirected_to(conn) == "/"
      refute get_session(conn, :locale) == "xx"
    end

    test "ignores missing locale param and redirects", %{conn: conn} do
      conn = post(conn, ~p"/locale", %{})

      assert redirected_to(conn) == "/"
    end

    test "updates user language in DB when logged in", %{conn: conn} do
      user = user_fixture(%{language: "de"})

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/locale", %{"locale" => "es"})

      assert redirected_to(conn)
      assert get_session(conn, :locale) == "es"

      # Verify DB was updated
      updated_user = Animina.Repo.get!(Animina.Accounts.User, user.id)
      assert updated_user.language == "es"
    end

    test "accepts all supported locales", %{conn: _conn} do
      for locale <- ~w(de en tr ru ar pl fr es uk) do
        conn = post(build_conn(), ~p"/locale", %{"locale" => locale})
        assert redirected_to(conn) == "/"
        assert get_session(conn, :locale) == locale
      end
    end
  end
end
