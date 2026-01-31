defmodule AniminaWeb.UserLive.EditProfileTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts

  describe "Edit Profile page" do
    test "renders edit profile form", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/profile")

      assert html =~ "Edit Profile"
      assert html =~ "Display Name"
      assert html =~ "Height"
      assert html =~ "Occupation"
      assert html =~ "Language"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/profile")

      assert page_title(lv) == "Edit Profile"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/profile")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
      assert html =~ "Edit Profile"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings/profile")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "updates user profile successfully", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/profile")

      lv
      |> form("#profile_form", %{
        "user" => %{
          "display_name" => "New Name",
          "height" => "175",
          "occupation" => "Developer",
          "language" => "en"
        }
      })
      |> render_submit()

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.display_name == "New Name"
      assert updated_user.height == 175
      assert updated_user.occupation == "Developer"
    end

    test "validates display_name length", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/profile")

      result =
        lv
        |> form("#profile_form", %{
          "user" => %{"display_name" => "A"}
        })
        |> render_submit()

      assert result =~ "should be at least 2 character(s)"
    end

    test "validates height range", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/profile")

      result =
        lv
        |> form("#profile_form", %{
          "user" => %{"height" => "50"}
        })
        |> render_submit()

      assert result =~ "must be greater than or equal to 80"
    end

    test "has back link to settings hub in breadcrumbs", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/profile")

      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
    end
  end
end
