defmodule AniminaWeb.UserLive.ResetPasswordTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts
  alias Animina.Accounts.UserToken
  alias Animina.Repo

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_password_reset_instructions(user, url)
      end)

    %{user: user, token: token}
  end

  describe "reset password page" do
    test "renders reset password page with valid token", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password/#{token}")

      assert html =~ "Set new password"
    end

    test "redirects to login with flash for invalid token", %{conn: conn} do
      {:ok, conn} =
        conn
        |> live(~p"/users/reset-password/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert conn.resp_body =~ "Password reset link is invalid or expired."
    end

    test "redirects to login with flash for expired token", %{conn: conn, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      {:ok, conn} =
        conn
        |> live(~p"/users/reset-password/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert conn.resp_body =~ "Password reset link is invalid or expired."
    end
  end

  describe "reset password form" do
    test "resets password with valid data", %{conn: conn, user: user, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      result =
        lv
        |> form("#reset_password_form",
          user: %{password: "new valid password", password_confirmation: "new valid password"}
        )
        |> render_submit()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} = result

      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "shows validation errors for short password", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      result =
        lv
        |> form("#reset_password_form",
          user: %{password: "short", password_confirmation: "short"}
        )
        |> render_submit()

      assert result =~ "should be at least 12 character(s)"
    end

    test "shows validation errors for mismatched password confirmation", %{
      conn: conn,
      token: token
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      result =
        lv
        |> form("#reset_password_form",
          user: %{password: "new valid password", password_confirmation: "does not match"}
        )
        |> render_submit()

      assert result =~ "does not match password"
    end

    test "deletes all tokens after successful reset", %{conn: conn, user: user, token: token} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      lv
      |> form("#reset_password_form",
        user: %{password: "new valid password", password_confirmation: "new valid password"}
      )
      |> render_submit()

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end
end
