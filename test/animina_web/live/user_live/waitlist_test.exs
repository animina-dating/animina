defmodule AniminaWeb.UserLive.WaitlistTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Waitlist page" do
    test "renders waitlist message for authenticated user", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "Waitlist"
      assert html =~ user.display_name
      assert html =~ "not enough users"
      assert html =~ "too many new registrations"
      assert html =~ "server hardware"
    end

    test "renders countdown hook with data attributes", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "phx-hook=\"WaitlistCountdown\""
      assert html =~ "data-end-waitlist-at"
      assert html =~ "data-locale=\"en\""
    end

    test "shows processing text when end_waitlist_at is in the past", %{conn: conn} do
      user = user_fixture(language: "en")

      # Set end_waitlist_at to the past
      import Ecto.Query

      from(u in Animina.Accounts.User, where: u.id == ^user.id)
      |> Animina.Repo.update_all(
        set: [end_waitlist_at: DateTime.add(DateTime.utc_now(), -1, :day)]
      )

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "being processed"
    end

    test "redirects to login if not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/waitlist")
      assert {:redirect, %{to: "/users/log-in"}} = redirect
    end

    test "displays user's referral code", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ user.referral_code
      assert html =~ "Your referral code"
      assert html =~ "Copy code"
    end

    test "shows referral count and progress", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      # Default threshold is 3 (from system settings)
      assert html =~ "0/3 referrals"
      assert html =~ "Get activated faster"
    end
  end
end
