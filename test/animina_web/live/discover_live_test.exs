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
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      # Wait for async load
      html = render(lv)

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

      assert page_title(lv) == "Discover - ANIMINA"
    end

    test "shows Your Matches section", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      # Wait for async load to complete
      html = render(lv)
      assert html =~ "Your Matches"
    end

    test "shows Wildcards section", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      # Wait for async load to complete
      html = render(lv)
      assert html =~ "Wildcards"
      assert html =~ "Random picks"
    end

    test "shows empty state with adjust preferences link", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      # Wait for async load to complete
      html = render(lv)
      assert html =~ "No suggestions available"
      assert html =~ "Adjust Preferences"
    end

    test "shows info panel inside a details element", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      assert html =~ "<details"
      assert html =~ "How Discovery Works"
    end

    test "does not show conflict count (security fix)", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      html = render(lv)
      # The page should NOT show specific conflict counts
      refute html =~ "potential conflict"
    end

    test "profile cards have no chat icon button", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/discover")

      html = render(lv)
      # Chat icon and related text should not appear on discover cards
      refute html =~ "Send message"
      refute html =~ "No free chat slots"
    end

    test "shows loading skeletons in disconnected render", %{conn: conn} do
      conn =
        conn
        |> log_in_user(user_fixture(language: "en"))

      html = conn |> get(~p"/discover") |> html_response(200)

      assert html =~ "skeleton-card"
      assert html =~ "animate-pulse"
    end
  end
end
