defmodule AniminaWeb.UserLive.SettingsHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Settings Hub page" do
    test "renders settings hub with account and profile links", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      assert html =~ "Account Security"
      assert html =~ "Delete Account"
      assert html =~ "Passkeys"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      assert page_title(lv) == "My Profile & Settings - ANIMINA"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "account and profile navigation links are present", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      # Account links
      assert has_element?(lv, "main a[href='/settings/language']")
      assert has_element?(lv, "main a[href='/settings/account']")
      assert has_element?(lv, "main a[href='/settings/passkeys']")
      assert has_element?(lv, "main a[href='/settings/delete-account']")
      # Profile links should now be in the settings main content
      assert has_element?(lv, "main a[href='/settings/avatar']")
      assert has_element?(lv, "main a[href='/settings/profile']")
      assert has_element?(lv, "main a[href='/settings/moodboard']")
      assert has_element?(lv, "main a[href='/settings/traits']")
      assert has_element?(lv, "main a[href='/settings/preferences']")
      assert has_element?(lv, "main a[href='/settings/locations']")
    end

    test "profile summary shows user display name and email", %{conn: conn} do
      user = user_fixture(language: "en", display_name: "Maria Schmidt")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings")

      assert html =~ "Maria Schmidt"
      assert html =~ user.email
    end

    test "section headings render", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      assert has_element?(lv, "main h2", "My Profile")
      assert has_element?(lv, "main h2", "App")
      assert has_element?(lv, "main h2", "Account")
    end

    test "shows profile completeness progress bar", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      assert html =~ "Profile completeness"
    end
  end
end
