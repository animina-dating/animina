defmodule AniminaWeb.UserLive.WaitlistTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures
  import Animina.TraitsFixtures
  import Animina.MoodboardFixtures

  describe "Waitlist page" do
    test "renders waitlist page with welcome message", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

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
      assert html =~ "Invite friends"
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
      assert html =~ "Invite friends"
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

    test "shows avatar thumbnail when user has approved avatar photo", %{conn: conn} do
      user = user_fixture(language: "en")

      approved_photo_fixture(%{
        owner_type: "User",
        owner_id: user.id,
        type: "avatar"
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      # Should show the avatar thumbnail image instead of the icon
      assert html =~ "waitlist-avatar"
      assert html =~ "/photos/"
    end

    test "shows flag count when user has flags set", %{conn: conn} do
      user = user_fixture(language: "en")

      flag1 = flag_fixture()
      flag2 = flag_fixture()

      Animina.Traits.add_user_flag(%{
        user_id: user.id,
        flag_id: flag1.id,
        color: "white",
        position: 1
      })

      Animina.Traits.add_user_flag(%{
        user_id: user.id,
        flag_id: flag2.id,
        color: "green",
        position: 2
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "2 flags set"
    end

    test "shows moodboard item count when user has moodboard items", %{conn: conn} do
      user = user_fixture(language: "en")

      story_moodboard_item_fixture(user, "My story")
      story_moodboard_item_fixture(user, "Another story", %{position: 1})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      # Should show count with "items" (at least 2 items created)
      assert html =~ ~r/\d+ items/
    end

    test "shows blocked contacts count when user has blocked contacts", %{conn: conn} do
      user = user_fixture(language: "en")

      Animina.Accounts.add_contact_blacklist_entry(user, %{
        value: "+4915112345678",
        label: "Test"
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "1 contact blocked"
    end

    test "shows original descriptions for incomplete cards", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      assert html =~ "Upload your main profile photo."
      assert html =~ "Define what you&#39;re about and what you&#39;re looking for."
      assert html =~ "Add photos and stories to make a great first impression."
    end

    test "renders column toggle with default 2 columns", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      # Column toggle should be present
      assert html =~ "change_columns"
      # Default is 2 columns — grid should have grid-cols-2
      assert html =~ "grid-cols-2"
    end

    test "change_columns event updates the card grid layout", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/waitlist")

      # Switch to 3 columns
      html = lv |> element(~s|button[phx-value-columns="3"]|) |> render_click()
      assert html =~ "grid-cols-3"

      # Switch to 1 column
      html = lv |> element(~s|button[phx-value-columns="1"]|) |> render_click()
      assert html =~ "grid-cols-1"
    end
  end
end
