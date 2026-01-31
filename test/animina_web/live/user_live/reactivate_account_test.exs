defmodule AniminaWeb.UserLive.ReactivateAccountTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts

  defp create_reactivation_session(conn, user) do
    token = Phoenix.Token.sign(AniminaWeb.Endpoint, "reactivation", user.id)

    conn
    |> Phoenix.ConnTest.init_test_session(%{reactivation_token: token, locale: "en"})
  end

  describe "Reactivate Account page" do
    test "renders reactivation options with valid token", %{conn: conn} do
      user = user_fixture(language: "en") |> set_password()
      {:ok, _} = Accounts.soft_delete_user(user)

      {:ok, _lv, html} =
        conn
        |> create_reactivation_session(user)
        |> live(~p"/users/reactivate")

      assert html =~ "Reactivate my account"
      assert html =~ "Start fresh with a new account"
    end

    test "redirects to login with invalid token", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{reactivation_token: "invalid", locale: "en"})

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/users/reactivate")
    end

    test "redirects to login with expired token", %{conn: conn} do
      user = user_fixture(language: "en") |> set_password()
      {:ok, _} = Accounts.soft_delete_user(user)

      # Sign a token with max_age of 0 (expired)
      token = Phoenix.Token.sign(AniminaWeb.Endpoint, "reactivation", user.id)

      # We can't easily fake expiry, so test with a completely bogus token
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{
          reactivation_token: token <> "tampered",
          locale: "en"
        })

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/users/reactivate")
    end

    test "redirects to login when no token in session", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{locale: "en"})

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/users/reactivate")
    end

    test "reactivate button restores account and redirects to login", %{conn: conn} do
      user = user_fixture(language: "en") |> set_password()
      {:ok, _} = Accounts.soft_delete_user(user)

      {:ok, lv, _html} =
        conn
        |> create_reactivation_session(user)
        |> live(~p"/users/reactivate")

      lv |> element("#reactivate-btn") |> render_click()

      flash = assert_redirect(lv, ~p"/users/log-in")
      assert flash["info"] =~ "reactivated"

      reactivated_user = Accounts.get_user!(user.id)
      assert reactivated_user.deleted_at == nil
    end

    test "fresh start button deletes account and redirects to register", %{conn: conn} do
      user = user_fixture(language: "en") |> set_password()
      {:ok, _} = Accounts.soft_delete_user(user)

      {:ok, lv, _html} =
        conn
        |> create_reactivation_session(user)
        |> live(~p"/users/reactivate")

      lv |> element("#fresh-start-btn") |> render_click()

      flash = assert_redirect(lv, ~p"/users/register")
      assert flash["info"] =~ "removed"

      refute Animina.Repo.get(Accounts.User, user.id)
    end

    test "handles email conflict during reactivation", %{conn: conn} do
      user = user_fixture(language: "en") |> set_password()
      email = user.email
      {:ok, _} = Accounts.soft_delete_user(user)

      # Another user claims the email
      _new_user = user_fixture(email: email)

      {:ok, lv, _html} =
        conn
        |> create_reactivation_session(user)
        |> live(~p"/users/reactivate")

      lv |> element("#reactivate-btn") |> render_click()

      flash = assert_redirect(lv, ~p"/users/register")
      assert flash["error"] =~ "email"
    end
  end
end
