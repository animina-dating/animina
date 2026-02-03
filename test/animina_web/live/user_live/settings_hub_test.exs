defmodule AniminaWeb.UserLive.SettingsHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures
  import Animina.TraitsFixtures

  alias Animina.Traits

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
      assert html =~ "My Flags"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      assert page_title(lv) == "Settings"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "all 8 navigation links are present with correct paths", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      assert has_element?(lv, "a[href='/users/settings/avatar']")
      assert has_element?(lv, "a[href='/users/settings/profile']")
      assert has_element?(lv, "a[href='/users/settings/preferences']")
      assert has_element?(lv, "a[href='/users/settings/account']")
      assert has_element?(lv, "a[href='/users/settings/delete-account']")
      assert has_element?(lv, "a[href='/users/settings/language']")
      assert has_element?(lv, "a[href='/users/settings/locations']")
      assert has_element?(lv, "a[href='/users/settings/traits']")
    end

    test "profile summary shows user display name and email", %{conn: conn} do
      user = user_fixture(language: "en", display_name: "Maria Schmidt")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Maria Schmidt"
      assert html =~ user.email
    end

    test "section headings render", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      assert html =~ "Profile &amp; Matching"
      assert has_element?(lv, "h2", "App")
      assert has_element?(lv, "h2", "Account")
    end

    test "shows flag counts", %{conn: conn} do
      user = user_fixture(language: "en")

      category = category_fixture()
      flag = flag_fixture(%{category_id: category.id})

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          position: 1
        })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "1 white"
    end

    test "shows age in profile preview", %{conn: conn} do
      user = user_fixture(language: "en", birthday: ~D[1990-01-01])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # The user born 1990-01-01 should be 36 years old in 2026
      assert html =~ "36 years"
    end

    test "shows location city names", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # User fixture creates location with zip 10115 which is Berlin
      assert html =~ "Berlin"
    end

    test "shows Profile Photo card in settings", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings")

      assert html =~ "Profile Photo"
      assert has_element?(lv, "a[href='/users/settings/avatar']")
    end

    test "shows No photo preview when no avatar", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "No photo"
    end

    test "shows Photo uploaded preview when avatar is approved", %{conn: conn} do
      user = user_fixture(language: "en")
      _avatar = approved_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Photo uploaded"
    end

    test "shows Processing preview when avatar is pending", %{conn: conn} do
      user = user_fixture(language: "en")
      _avatar = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Processing"
    end
  end
end
