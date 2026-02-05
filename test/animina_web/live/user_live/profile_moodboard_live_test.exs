defmodule AniminaWeb.UserLive.ProfileMoodboardLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts.Roles
  alias Animina.FeatureFlags

  describe "ProfileMoodboardLive access control" do
    test "owner can access their own moodboard", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/moodboard/#{user.id}")

      assert html =~ "Moodboard"
      assert html =~ user.display_name
    end

    test "anonymous user sees vague denial and is redirected to /", %{conn: conn} do
      user = user_fixture(language: "en")

      assert {:error, redirect} = live(conn, ~p"/moodboard/#{user.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "logged-in non-owner sees vague denial and is redirected to /", %{conn: conn} do
      owner = user_fixture(language: "en")
      other_user = user_fixture(language: "en")

      assert {:error, redirect} =
               conn
               |> log_in_user(other_user)
               |> live(~p"/moodboard/#{owner.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "non-existent user_id shows same vague denial (indistinguishable from non-owner)", %{
      conn: conn
    } do
      random_uuid = Ecto.UUID.generate()

      assert {:error, redirect} = live(conn, ~p"/moodboard/#{random_uuid}")

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
               |> live(~p"/moodboard/#{random_uuid}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end
  end

  describe "ProfileMoodboardLive admin access" do
    setup do
      # Ensure the flag is disabled by default
      FeatureFlags.disable(:admin_view_moodboards)
      :ok
    end

    test "admin cannot view others' moodboards when flag is disabled", %{conn: conn} do
      owner = user_fixture(language: "en")
      admin_user = user_fixture(language: "en")
      {:ok, _} = Roles.assign_role(admin_user, "admin")

      assert {:error, redirect} =
               conn
               |> log_in_user(admin_user, current_role: "admin")
               |> live(~p"/moodboard/#{owner.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "admin can view others' moodboards when flag is enabled", %{conn: conn} do
      owner = user_fixture(language: "en")
      admin_user = user_fixture(language: "en")
      {:ok, _} = Roles.assign_role(admin_user, "admin")

      # Enable the flag
      FeatureFlags.enable(:admin_view_moodboards)

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin_user, current_role: "admin")
        |> live(~p"/moodboard/#{owner.id}")

      assert html =~ "Moodboard"
      assert html =~ owner.display_name
    end

    test "admin viewing others' moodboards does not see Edit button", %{conn: conn} do
      owner = user_fixture(language: "en")
      admin_user = user_fixture(language: "en")
      {:ok, _} = Roles.assign_role(admin_user, "admin")

      FeatureFlags.enable(:admin_view_moodboards)

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin_user, current_role: "admin")
        |> live(~p"/moodboard/#{owner.id}")

      refute html =~ "Edit Moodboard"
    end

    test "moderator cannot view others' moodboards even with flag enabled", %{conn: conn} do
      owner = user_fixture(language: "en")
      mod_user = user_fixture(language: "en")
      {:ok, _} = Roles.assign_role(mod_user, "moderator")

      FeatureFlags.enable(:admin_view_moodboards)

      assert {:error, redirect} =
               conn
               |> log_in_user(mod_user, current_role: "moderator")
               |> live(~p"/moodboard/#{owner.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end
  end
end
