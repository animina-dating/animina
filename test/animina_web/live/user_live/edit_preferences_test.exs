defmodule AniminaWeb.UserLive.EditPreferencesTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts

  describe "Edit Preferences page" do
    test "renders preferences form", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/preferences")

      assert html =~ "Partner Preferences"
      assert html =~ "Preferred Partner Gender"
      assert html =~ "Minimum Age"
      assert html =~ "Maximum Age"
      assert html =~ "Search Radius"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/preferences")

      assert page_title(lv) == "Partner Preferences - ANIMINA"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/preferences")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
      assert html =~ "Partner Preferences"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings/preferences")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "updates partner preferences", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/preferences")

      lv
      |> form("#preferences_form", %{
        "user" => %{
          "search_radius" => "100",
          "partner_height_min" => "160",
          "partner_height_max" => "200"
        }
      })
      |> render_submit()

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.search_radius == 100
      assert updated_user.partner_height_min == 160
      assert updated_user.partner_height_max == 200
    end

    test "has back link to settings hub in breadcrumbs", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/preferences")

      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
    end
  end
end
