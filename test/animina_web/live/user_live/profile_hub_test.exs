defmodule AniminaWeb.UserLive.ProfileHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Profile Hub page" do
    test "renders page with all 6 profile links", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my-profile")

      assert html =~ "My Profile"

      assert has_element?(lv, "main a[href='/users/settings/avatar']")
      assert has_element?(lv, "main a[href='/users/settings/profile']")
      assert has_element?(lv, "main a[href='/users/settings/moodboard']")
      assert has_element?(lv, "main a[href='/users/settings/traits']")
      assert has_element?(lv, "main a[href='/users/settings/preferences']")
      assert has_element?(lv, "main a[href='/users/settings/locations']")
    end

    test "shows completion indicators", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my-profile")

      # Fresh user has incomplete items — should show empty circle indicators
      assert html =~ "border-base-content/20"
    end

    test "shows progress bar when not fully complete", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my-profile")

      assert html =~ "Profile completeness"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my-profile")

      assert page_title(lv) == "My Profile"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my-profile")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end
end
