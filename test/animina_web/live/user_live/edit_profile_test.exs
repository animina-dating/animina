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
        |> live(~p"/settings/profile/info")

      assert html =~ "Edit Profile"
      assert html =~ "First name"
      assert html =~ "Last name"
      assert html =~ "Display Name"
      assert html =~ "Height"
      assert html =~ "Occupation"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile/info")

      assert page_title(lv) == "Edit Profile - ANIMINA"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile/info")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/settings/profile']")
      assert html =~ "Edit Profile"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/profile/info")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "updates user profile successfully", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/profile/info")

      lv
      |> form("#profile_form", %{
        "user" => %{
          "first_name" => "Stefan",
          "last_name" => "Wintermeyer",
          "display_name" => "New Name",
          "height" => "175",
          "occupation" => "Developer"
        }
      })
      |> render_submit()

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.first_name == "Stefan"
      assert updated_user.last_name == "Wintermeyer"
      assert updated_user.display_name == "New Name"
      assert updated_user.height == 175
      assert updated_user.occupation == "Developer"
    end

    test "validates display_name length", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile/info")

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
        |> live(~p"/settings/profile/info")

      result =
        lv
        |> form("#profile_form", %{
          "user" => %{"height" => "50"}
        })
        |> render_submit()

      assert result =~ "must be greater than or equal to 80"
    end

    test "displays birthdate as a disabled field", %{conn: conn} do
      user = user_fixture(language: "en", birthday: ~D[1990-05-15])

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/profile/info")

      assert html =~ "Birthday"
      assert html =~ "1990-05-15"
      assert has_element?(lv, "input[disabled]")
    end

    test "shows note that birthdate cannot be changed", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/profile/info")

      assert html =~ "This field cannot be changed."
    end
  end
end
