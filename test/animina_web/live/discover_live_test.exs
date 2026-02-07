defmodule AniminaWeb.DiscoverLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Discover page" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/discover")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders discover page without tabs", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "Discover"
      # No tab buttons should be present
      refute html =~ "Safe"
      refute html =~ "Attracted"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert page_title(lv) == "Discover"
    end

    test "shows Your Matches section", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "Your Matches"
      assert html =~ "Smart suggestions based on your preferences and compatibility"
    end

    test "shows Wildcards section", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "Wildcards"
      assert html =~ "Random picks"
    end

    test "shows empty state when no suggestions", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "No suggestions available"
    end

    test "shows slot status bar", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "active chats"
      assert html =~ "new chats remaining today"
    end

    test "shows info panel explaining how discovery works", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "How Discovery Works"
    end

    test "does not show conflict count (security fix)", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      # The page should NOT show specific conflict counts
      refute html =~ "potential conflict"
    end

    test "shows dismissed count", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "0 dismissed"
    end
  end
end
