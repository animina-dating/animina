defmodule AniminaWeb.UserLive.ProfileHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Profile Hub page" do
    test "renders profile cards with navigation links", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile")

      assert has_element?(lv, "main a[href='/settings/profile/photo']")
      assert has_element?(lv, "main a[href='/settings/profile/info']")
      assert has_element?(lv, "main a[href='/settings/profile/moodboard']")
      assert has_element?(lv, "main a[href='/settings/profile/traits']")
      assert has_element?(lv, "main a[href='/settings/profile/preferences']")
      assert has_element?(lv, "main a[href='/settings/profile/locations']")
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile")

      assert page_title(lv) == "My Profile - ANIMINA"
    end

    test "profile summary shows display name and email", %{conn: conn} do
      user = user_fixture(language: "en", display_name: "Maria Schmidt")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/profile")

      assert html =~ "Maria Schmidt"
      assert html =~ user.email
    end

    test "shows profile completeness progress bar", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile")

      assert html =~ "Profile completeness"
    end

    test "shows My Profile section heading", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile")

      assert has_element?(lv, "main h2", "My Profile")
    end

    test "has breadcrumb to settings", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile")

      assert has_element?(lv, ".breadcrumbs a[href='/settings']")
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/profile")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end
end
