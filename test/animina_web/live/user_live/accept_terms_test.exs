defmodule AniminaWeb.UserLive.AcceptTermsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Ecto.Query, warn: false

  defp user_without_tos do
    user = user_fixture()

    Animina.Repo.update_all(
      Ecto.Query.from(u in Animina.Accounts.User, where: u.id == ^user.id),
      set: [tos_accepted_at: nil]
    )

    Animina.Repo.get!(Animina.Accounts.User, user.id)
  end

  describe "GET /users/accept-terms" do
    test "redirects to login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/users/accept-terms")
      assert path =~ "/users/log-in"
    end

    test "renders the accept terms page for user without tos_accepted_at", %{conn: conn} do
      user = user_without_tos()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/accept-terms")

      assert html =~ "Updated Terms of Service"
      assert html =~ "Accept and continue"
      assert html =~ "Decline and log out"
      assert html =~ ~s(href="/agb")
      assert html =~ ~s(href="/datenschutz")
    end
  end

  describe "accepting terms" do
    test "sets tos_accepted_at and redirects to settings", %{conn: conn} do
      user = user_without_tos()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/accept-terms")

      lv
      |> form("#accept_tos_form", tos_accepted: "true")
      |> render_submit()

      {path, flash} = assert_redirect(lv)
      assert path == "/users/settings"
      assert flash["info"] =~ "Terms of Service accepted"

      updated_user = Animina.Repo.get!(Animina.Accounts.User, user.id)
      assert updated_user.tos_accepted_at != nil
    end
  end

  describe "declining terms" do
    test "redirects to home page", %{conn: conn} do
      user = user_without_tos()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/accept-terms")

      lv |> element("button", "Decline and log out") |> render_click()

      {path, _flash} = assert_redirect(lv)
      assert path == "/"
    end
  end

  describe "ToS gate for authenticated routes" do
    test "user without tos_accepted_at is redirected to accept-terms from settings", %{
      conn: conn
    } do
      user = user_without_tos()

      {:error, {:redirect, %{to: path}}} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert path == "/users/accept-terms"
    end

    test "user with tos_accepted_at can access settings", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Settings"
    end
  end
end
