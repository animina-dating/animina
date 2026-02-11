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
      assert html =~ "Discover"
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

    test "hides discover and messages for waitlisted user, shows waitlist card", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      refute has_element?(lv, "main a[href='/discover']")
      refute has_element?(lv, "main a[href='/my/messages']")
      assert has_element?(lv, "main a[href='/my/waitlist']")
      assert html =~ "Waitlist"
    end
  end
end
