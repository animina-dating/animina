defmodule AniminaWeb.UserLive.ProfileMoodboardTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts
  alias Animina.Accounts.Roles

  describe "ProfileMoodboard access control" do
    test "owner can access their own moodboard", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      assert html =~ "Moodboard"
      assert html =~ user.display_name
    end

    test "displays height, gender icon, and occupation on moodboard", %{conn: conn} do
      user =
        user_fixture(
          language: "en",
          height: 175,
          gender: "female",
          occupation: "Software Engineer"
        )

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      # Check height is displayed (175 cm -> 1,75 m)
      assert html =~ "1,75 m"

      # Check gender icon is displayed (female symbol ♀)
      assert html =~ "♀"

      # Check occupation is displayed
      assert html =~ "Software Engineer"
    end

    test "displays male gender icon", %{conn: conn} do
      user = user_fixture(language: "en", gender: "male")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      # Check male gender icon is displayed (♂)
      assert html =~ "♂"
    end

    test "does not display occupation when not set", %{conn: conn} do
      user = user_fixture(language: "en", occupation: nil)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      # Occupation paragraph should not appear
      refute html =~ ~r/<p[^>]*class="text-base-content\/60">\s*[^<]+\s*<\/p>\s*<\/div>\s*<\.link/
    end

    test "page title includes display name, gender, age, height, and location", %{conn: conn} do
      user = user_fixture(language: "en", height: 172, gender: "female", display_name: "Jane Doe")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      # Page title should include: Display Name · ♀ XX years · 1,72 m · City
      assert html =~ "<title"
      assert html =~ "Jane Doe"
      assert html =~ "♀"
      assert html =~ "1,72 m"
      assert html =~ "Berlin"
    end

    test "anonymous user sees vague denial and is redirected to /", %{conn: conn} do
      user = user_fixture(language: "en")

      assert {:error, redirect} = live(conn, ~p"/users/#{user.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "logged-in non-owner without spotlight/conversation sees restricted profile", %{
      conn: conn
    } do
      owner = user_fixture(language: "en")
      other_user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/users/#{owner.id}")

      assert html =~ owner.display_name
      assert html =~ "This profile is only visible"
      refute html =~ "Edit Moodboard"
    end

    test "logged-in non-owner with conversation can view moodboard", %{conn: conn} do
      owner = user_fixture(language: "en")
      other_user = user_fixture(language: "en")
      {:ok, _conv} = Animina.Messaging.get_or_create_conversation(other_user.id, owner.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/users/#{owner.id}")

      assert html =~ owner.display_name
      refute html =~ "This profile is only visible"
    end

    test "non-existent user_id shows same vague denial (indistinguishable from non-owner)", %{
      conn: conn
    } do
      random_uuid = Ecto.UUID.generate()

      assert {:error, redirect} = live(conn, ~p"/users/#{random_uuid}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "non-existent user_id shows same denial for logged-in user", %{conn: conn} do
      user = user_fixture(language: "en")
      random_uuid = Ecto.UUID.generate()

      assert {:error, redirect} =
               conn
               |> log_in_user(user)
               |> live(~p"/users/#{random_uuid}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end
  end

  describe "ProfileMoodboard activity heatmap" do
    test "owner sees activity heatmap when online status is visible", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      assert html =~ "Activity"
      assert html =~ "<svg"
      assert html =~ "Less"
      assert html =~ "More"
    end

    test "heatmap is hidden when user has hide_online_status enabled", %{conn: conn} do
      user = user_fixture(language: "en")
      {:ok, user} = Accounts.update_online_status_visibility(user, %{hide_online_status: true})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      # The heatmap section should not be present
      refute html =~ "activity-heatmap"
    end

    test "non-owner sees heatmap when profile user allows online status", %{conn: conn} do
      owner = user_fixture(language: "en")
      viewer = user_fixture(language: "en")
      {:ok, _conv} = Animina.Messaging.get_or_create_conversation(viewer.id, owner.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/users/#{owner.id}")

      assert html =~ "activity-heatmap"
    end

    test "non-owner does not see heatmap when profile user hides online status", %{conn: conn} do
      owner = user_fixture(language: "en")
      {:ok, _owner} = Accounts.update_online_status_visibility(owner, %{hide_online_status: true})
      viewer = user_fixture(language: "en")
      {:ok, _conv} = Animina.Messaging.get_or_create_conversation(viewer.id, owner.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/users/#{owner.id}")

      refute html =~ "activity-heatmap"
    end
  end

  describe "ProfileMoodboard admin access" do
    test "admin can view others' moodboards", %{conn: conn} do
      owner = user_fixture(language: "en")
      admin_user = user_fixture(language: "en")
      {:ok, _} = Roles.assign_role(admin_user, "admin")

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin_user, current_role: "admin")
        |> live(~p"/users/#{owner.id}")

      assert html =~ "Moodboard"
      assert html =~ owner.display_name
    end

    test "admin viewing others' moodboards does not see Edit button", %{conn: conn} do
      owner = user_fixture(language: "en")
      admin_user = user_fixture(language: "en")
      {:ok, _} = Roles.assign_role(admin_user, "admin")

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin_user, current_role: "admin")
        |> live(~p"/users/#{owner.id}")

      refute html =~ "Edit Moodboard"
    end
  end
end
