defmodule AniminaWeb.UserLive.SettingsHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Settings Hub page" do
    test "renders settings hub with all links", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      assert html =~ "Settings"
      assert html =~ "Edit Profile"
      assert html =~ "Partner Preferences"
      assert html =~ "Account Security"
      assert html =~ "Delete Account"
      assert html =~ "Locations"
      assert html =~ "Language"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      assert page_title(lv) == "Settings"
    end

    test "does not render breadcrumbs", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      refute html =~ "breadcrumbs"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "links navigate to sub-pages", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      assert has_element?(lv, "a[href='/users/settings/profile']")
      assert has_element?(lv, "a[href='/users/settings/preferences']")
      assert has_element?(lv, "a[href='/users/settings/account']")
      assert has_element?(lv, "a[href='/users/settings/delete-account']")
      assert has_element?(lv, "a[href='/users/settings/language']")
      assert has_element?(lv, "a[href='/users/settings/locations']")
    end
  end
end
