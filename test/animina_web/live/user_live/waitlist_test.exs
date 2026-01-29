defmodule AniminaWeb.UserLive.WaitlistTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Waitlist page" do
    test "renders waitlist message for authenticated user", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "Warteliste"
      assert html =~ user.display_name
      assert html =~ "zu wenige Nutzer"
      assert html =~ "zu viele Nutzer"
      assert html =~ "Server-Hardware"
      assert html =~ "4 Wochen"
    end

    test "redirects to login if not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/waitlist")
      assert {:redirect, %{to: "/users/log-in"}} = redirect
    end
  end
end
