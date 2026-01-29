defmodule AniminaWeb.UserLive.PinConfirmationTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts
  alias Animina.Repo

  defp create_user_with_pin(_context) do
    user = unconfirmed_user_fixture()
    {:ok, pin} = Accounts.send_confirmation_pin(user)
    token = Phoenix.Token.sign(AniminaWeb.Endpoint, "pin_confirmation", user.id)
    %{user: user, pin: pin, token: token}
  end

  describe "PIN confirmation page" do
    setup [:create_user_with_pin]

    test "renders the PIN input form", %{conn: conn, token: token, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm/#{token}")

      assert html =~ "E-Mail bestätigen"
      assert html =~ user.email
      assert html =~ "Bestätigungscode"
      assert html =~ "Verbleibende Versuche"
      assert html =~ "3"
    end

    test "redirects with invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> live(~p"/users/confirm/invalid-token")
        |> follow_redirect(conn, ~p"/users/register")

      assert html =~ "ungültig oder abgelaufen"
    end

    test "confirms user with correct PIN", %{conn: conn, token: token, pin: pin} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      lv
      |> form("#pin_form", pin: %{"pin" => pin})
      |> render_submit()

      # Should trigger login form submission
      assert render(lv) =~ "pin_login_form"
    end

    test "shows error with wrong PIN", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      html =
        lv
        |> form("#pin_form", pin: %{"pin" => "000000"})
        |> render_submit()

      assert html =~ "Falscher Code"
      assert html =~ "2 Versuch(e)"
    end

    test "redirects after 3 wrong attempts", %{conn: conn, token: token, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      # First wrong attempt
      lv |> form("#pin_form", pin: %{"pin" => "000000"}) |> render_submit()

      # Second wrong attempt
      lv |> form("#pin_form", pin: %{"pin" => "000001"}) |> render_submit()

      # Third wrong attempt should redirect
      lv |> form("#pin_form", pin: %{"pin" => "000002"}) |> render_submit()

      flash = assert_redirect(lv, ~p"/users/register")
      assert flash["error"] =~ "gelöscht"

      # User should be deleted
      refute Repo.get(Animina.Accounts.User, user.id)
    end
  end
end
