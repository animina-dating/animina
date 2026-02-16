defmodule AniminaWeb.UserLive.MyHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  defp active_user do
    user = user_fixture(language: "en")

    user
    |> Ecto.Changeset.change(state: "normal")
    |> Animina.Repo.update!()
  end

  describe "My Hub page" do
    test "renders hub cards for active user", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      assert html =~ "My Hub"
      assert html =~ "Spotlight"
      assert html =~ "Messages"
      assert html =~ "Settings"
      assert html =~ "Logs"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      assert page_title(lv) == "My Hub - ANIMINA"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "navigation links are present for active user", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      assert has_element?(lv, "main a[href='/my/messages']")
      assert has_element?(lv, "main a[href='/my/settings']")
      assert has_element?(lv, "main a[href='/my/logs']")
    end

    test "does not show waitlist content for active user", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      refute html =~ "on the waitlist"
      refute html =~ "Prepare your profile"
    end

    test "shows waitlist status banner inline for waitlisted user", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "on the waitlist"
      assert html =~ "until your account is activated"
    end

    test "shows preparation section inline for waitlisted user", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "Prepare your profile"
      assert html =~ "Profile Photo"
      assert html =~ "Set up your flags"
      assert html =~ "Edit Moodboard"
    end

    test "shows referral code inline for waitlisted user", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ user.referral_code
      assert html =~ "Skip the waitlist"
    end

    test "still shows Settings and Logs cards for waitlisted user", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert has_element?(lv, "main a[href='/my/settings']")
      assert has_element?(lv, "main a[href='/my/logs']")
    end

    test "does not show waitlist as a hub card link for waitlisted user", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      refute has_element?(lv, "main a[href='/my/waitlist']")
    end

    test "hides Messages and Spotlight for waitlisted user", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      refute has_element?(lv, "main a[href='/my/spotlight']")
      refute has_element?(lv, "main a[href='/my/messages']")
    end
  end
end
