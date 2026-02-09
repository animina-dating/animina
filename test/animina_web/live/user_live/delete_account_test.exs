defmodule AniminaWeb.UserLive.DeleteAccountTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts

  describe "Delete Account page" do
    test "renders delete account page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/delete-account")

      assert html =~ "Delete Account"
      assert html =~ "30 days"
      assert html =~ "Confirm your password"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/delete-account")

      assert page_title(lv) == "Delete Account - ANIMINA"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/delete-account")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/settings']")
      assert html =~ "Delete Account"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/delete-account")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "soft-deletes user with correct password", %{conn: conn} do
      user = user_fixture(language: "en") |> set_password()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/delete-account")

      lv
      |> form("#delete_account_form", %{
        "user" => %{"password" => valid_user_password()}
      })
      |> render_submit()

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.deleted_at != nil
    end

    test "does not delete with wrong password", %{conn: conn} do
      user = user_fixture(language: "en") |> set_password()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/delete-account")

      lv
      |> form("#delete_account_form", %{
        "user" => %{"password" => "wrong_password!!"}
      })
      |> render_submit()

      assert render(lv) =~ "Invalid password"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.deleted_at == nil
    end

    test "has back link to settings hub in breadcrumbs", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/settings/delete-account")

      assert has_element?(lv, ".breadcrumbs a[href='/settings']")
    end
  end
end
