defmodule AniminaWeb.UserLive.ForgotPasswordTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "forgot password page" do
    test "renders the forgot password page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/forgot-password")

      assert html =~ "Forgot your password"
      assert html =~ "Back to login"
    end

    test "sends password reset email for existing user", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      result =
        lv
        |> form("#forgot_password_form", user: %{email: user.email})
        |> render_submit()

      assert result =~ "If an account exists with this email"
    end

    test "shows same message for non-existing email (no enumeration)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      result =
        lv
        |> form("#forgot_password_form", user: %{email: "nobody@example.com"})
        |> render_submit()

      assert result =~ "If an account exists with this email"
    end

    test "has a back to login link", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      {:ok, _login_live, login_html} =
        lv
        |> element("a", "Back to login")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end
end
