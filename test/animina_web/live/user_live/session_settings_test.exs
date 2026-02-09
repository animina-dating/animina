defmodule AniminaWeb.UserLive.SessionSettingsTest do
  use AniminaWeb.ConnCase, async: true

  alias Animina.Accounts

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Session Settings page" do
    test "renders session list", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/sessions")

      assert html =~ "Active Sessions"
      assert html =~ "This device"
    end

    test "has page title", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/sessions")

      assert page_title(lv) == "Active Sessions - ANIMINA"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings/sessions")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "shows multiple sessions", %{conn: conn} do
      user = user_fixture(language: "en")

      # Create an additional session
      Accounts.generate_user_session_token(user, %{
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64) Chrome/120",
        ip_address: "10.0.0.1"
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/sessions")

      # Should show current session + the one we created
      assert html =~ "This device"
      assert html =~ "10.0.0.1"
    end

    test "shows log out all other devices button when multiple sessions exist", %{conn: conn} do
      user = user_fixture(language: "en")

      Accounts.generate_user_session_token(user, %{
        user_agent: "Firefox",
        ip_address: "10.0.0.2"
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/sessions")

      assert html =~ "Log out all other devices"
    end
  end
end
