defmodule AniminaWeb.UserLive.EditLocationsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts

  describe "Edit Locations page" do
    test "renders locations page", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/locations")

      assert html =~ "Locations"
      assert html =~ "10115"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/locations")

      assert page_title(lv) == "Locations"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/locations")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
      assert html =~ "Locations"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings/locations")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "shows existing locations", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/locations")

      # User fixture creates a location with zip code 10115
      assert html =~ "10115"
    end

    test "adds a new location", %{conn: conn} do
      user = user_fixture(language: "en")
      germany_id = germany_id()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/locations")

      lv
      |> form("#location_form", %{
        "location" => %{
          "country_id" => germany_id,
          "zip_code" => "80331"
        }
      })
      |> render_submit()

      locations = Accounts.list_user_locations(user)
      assert length(locations) == 2
      assert Enum.any?(locations, &(&1.zip_code == "80331"))
    end

    test "removes a location when more than one exist", %{conn: conn} do
      user = user_fixture(language: "en")
      {:ok, _} = Accounts.add_user_location(user, %{country_id: germany_id(), zip_code: "80331"})
      locations = Accounts.list_user_locations(user)
      assert length(locations) == 2
      location = Enum.find(locations, &(&1.zip_code == "80331"))

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/locations")

      lv
      |> element("button[phx-click='remove_location'][phx-value-id='#{location.id}']")
      |> render_click()

      locations = Accounts.list_user_locations(user)
      assert length(locations) == 1
    end

    test "cannot remove the last location", %{conn: conn} do
      user = user_fixture(language: "en")
      assert length(Accounts.list_user_locations(user)) == 1

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/locations")

      # Remove button should not be rendered when there's only one location
      refute html =~ "phx-click=\"remove_location\""
    end

    test "has back link to settings hub in breadcrumbs", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/locations")

      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
    end
  end
end
