defmodule AniminaWeb.UserLive.LanguageSettingsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Language Settings page" do
    test "renders language settings with all language options", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/language")

      assert html =~ "Language"
      assert html =~ "🇩🇪"
      assert html =~ "🇬🇧"
      assert html =~ "🇹🇷"
      assert html =~ "🇷🇺"
      assert html =~ "🇸🇦"
      assert html =~ "🇵🇱"
      assert html =~ "🇫🇷"
      assert html =~ "🇪🇸"
      assert html =~ "🇺🇦"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/language")

      assert page_title(lv) == "Language - ANIMINA"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/language")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
      assert html =~ "Language"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings/language")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "has back link to settings hub in breadcrumbs", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/language")

      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
    end

    test "displays language names with flags", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/language")

      assert html =~ "Deutsch"
      assert html =~ "English"
      assert html =~ "Türkçe"
      assert html =~ "Français"
      assert html =~ "Español"
    end
  end
end
