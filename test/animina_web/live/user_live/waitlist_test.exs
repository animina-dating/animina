defmodule AniminaWeb.UserLive.WaitlistTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Waitlist page" do
    test "renders waitlist page with welcome message", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "Waitlist"
      assert html =~ user.display_name
      assert html =~ "on the waitlist"
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
      assert html =~ "Skip the waitlist"
    end

    test "shows links to avatar, moodboard editor and flag wizard", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "Prepare your profile"
      assert html =~ ~r"/users/settings/avatar"
      assert html =~ ~r"/users/settings/moodboard"
      assert html =~ ~r"/users/settings/traits"
    end

    test "shows completion checkmarks on profile preparation cards", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      # Fresh user has incomplete items — should show empty circle indicators
      assert html =~ "border-base-content/20"
    end

    test "shows passkey card as optional when user has no passkeys", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ ~r"/users/settings/passkeys"
      assert html =~ "Set up a passkey"
      assert html =~ "Optional"
    end

    test "shows passkey card with checkmark when user has passkeys", %{conn: conn} do
      user = user_fixture(language: "en")

      # Create a passkey for the user
      Animina.Accounts.create_user_passkey(user, %{
        credential_id: :crypto.strong_rand_bytes(32),
        public_key: %{
          1 => 2,
          3 => -7,
          -1 => 1,
          -2 => :crypto.strong_rand_bytes(32),
          -3 => :crypto.strong_rand_bytes(32)
        },
        sign_count: 0,
        label: "Test passkey"
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "Set up a passkey"
      assert html =~ "hero-check-circle-solid"
    end
  end
end
