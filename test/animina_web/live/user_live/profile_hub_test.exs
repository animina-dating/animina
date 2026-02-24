defmodule AniminaWeb.UserLive.ProfileHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Settings Hub shows profile cards" do
    test "renders profile cards with navigation links on /my/settings", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings")

      assert has_element?(lv, "main a[href='/my/settings/profile/photo']")
      assert has_element?(lv, "main a[href='/my/settings/profile/info']")
      assert has_element?(lv, "main a[href='/my/settings/profile/moodboard']")
      assert has_element?(lv, "main a[href='/my/settings/profile/traits']")
      assert has_element?(lv, "main a[href='/my/settings/profile/preferences']")
      assert has_element?(lv, "main a[href='/my/settings/profile/locations']")
    end

    test "shows profile completeness progress bar", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings")

      assert html =~ "Profile completeness"
    end

    test "shows Profile section heading", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings")

      assert has_element?(lv, "main h2", "Profile")
    end

    test "/my/settings/profile still works (redirects to settings hub)", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/profile")

      assert has_element?(lv, "main a[href='/my/settings/profile/photo']")
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end
end
