defmodule AniminaWeb.UserLive.SettingsHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Settings Hub page" do
    test "renders 4 category cards", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings")

      assert html =~ "Profile"
      assert html =~ "Privacy &amp; Blocking"
      assert html =~ "Account &amp; Security"
      assert html =~ "Language"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings")

      assert page_title(lv) == "Settings - ANIMINA"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "settings navigation links are present", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings")

      assert has_element?(lv, "main a[href='/my/settings/profile']")
      assert has_element?(lv, "main a[href='/my/settings/privacy']")
      assert has_element?(lv, "main a[href='/my/settings/account']")
      assert has_element?(lv, "main a[href='/my/settings/language']")
    end
  end
end
