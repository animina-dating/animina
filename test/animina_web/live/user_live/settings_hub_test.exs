defmodule AniminaWeb.UserLive.SettingsHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Settings Hub page" do
    test "renders settings hub with account links only", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      assert html =~ "Account Security"
      assert html =~ "Delete Account"
      assert html =~ "Passkeys"
      # Profile-only items should NOT appear in the settings hub content
      refute html =~ "Edit Profile"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      assert page_title(lv) == "Account - ANIMINA"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "account navigation links are present in settings content", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings")

      # These should be in the settings main content area
      assert has_element?(lv, "main a[href='/settings/language']")
      assert has_element?(lv, "main a[href='/settings/account']")
      assert has_element?(lv, "main a[href='/settings/passkeys']")
      assert has_element?(lv, "main a[href='/settings/delete-account']")
      # Profile links should NOT be in the settings main content
      refute has_element?(lv, "main a[href='/settings/avatar']")
      refute has_element?(lv, "main a[href='/settings/profile']")
      refute has_element?(lv, "main a[href='/settings/preferences']")
      refute has_element?(lv, "main a[href='/settings/traits']")
      refute has_element?(lv, "main a[href='/settings/locations']")
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

      assert has_element?(lv, "main h2", "App")
      assert has_element?(lv, "main h2", "Account")
      # Profile & Matching section should be gone from settings
      refute has_element?(lv, "main h2", "Profile & Matching")
    end
  end
end
