defmodule AniminaWeb.UserLive.LogsHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Logs Hub page" do
    test "renders logs hub with email history card", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/logs")

      assert html =~ "Email History"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/logs")

      assert page_title(lv) == "Logs - ANIMINA"
    end

    test "has breadcrumb to My ANIMINA", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/logs")

      assert has_element?(lv, ".breadcrumbs a[href='/my']")
    end

    test "has navigation link to email logs", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/logs")

      assert has_element?(lv, "main a[href='/my/logs/emails']")
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/logs")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end
end
