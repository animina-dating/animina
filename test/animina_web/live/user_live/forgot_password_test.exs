defmodule AniminaWeb.UserLive.ForgotPasswordTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "forgot password page" do
    test "renders the forgot password page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/forgot-password")

      assert html =~ "Passwort vergessen"
      assert html =~ "Zurück zur Anmeldung"
    end

    test "sends password reset email for existing user", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      result =
        lv
        |> form("#forgot_password_form", user: %{email: user.email})
        |> render_submit()

      assert result =~ "Falls ein Konto mit dieser E-Mail-Adresse existiert"
    end

    test "shows same message for non-existing email (no enumeration)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      result =
        lv
        |> form("#forgot_password_form", user: %{email: "nobody@example.com"})
        |> render_submit()

      assert result =~ "Falls ein Konto mit dieser E-Mail-Adresse existiert"
    end

    test "has a back to login link", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      {:ok, _login_live, login_html} =
        lv
        |> element("a", "Zurück zur Anmeldung")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Anmelden"
    end
  end
end
