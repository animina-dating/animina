defmodule AniminaWeb.UserLive.MyHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures
  import Animina.TraitsFixtures
  import Animina.MoodboardFixtures

  defp active_user do
    user = user_fixture(language: "en")

    user
    |> Ecto.Changeset.change(state: "normal")
    |> Animina.Repo.update!()
  end

  describe "My Hub page — active user" do
    test "renders hub cards for active user", %{conn: conn} do
      user = active_user()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "Hey #{user.display_name}!"
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

      assert page_title(lv) == "My Hub · ANIMINA"
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

    test "shows profile shortcuts section", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      assert html =~ "Your profile"
      assert html =~ "Profile Photo"
      assert html =~ "Set up your flags"
      assert html =~ "Edit Moodboard"
    end

    test "shows passkey and blocked contacts cards", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      assert html =~ "Set up a passkey"
      assert html =~ "Block contacts"
    end

    test "shows column toggle for active user", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      assert html =~ "change_columns"
    end

    test "change_columns event works for active user", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      html = lv |> element(~s|button[phx-value-columns="2"]|) |> render_click()
      assert html =~ "grid-cols-2"

      html = lv |> element(~s|button[phx-value-columns="1"]|) |> render_click()
      assert html =~ "grid-cols-1"
    end

    test "does not show referral card for active user", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      refute html =~ "Skip the waitlist"
      refute html =~ "referral-code"
    end

    test "does not show countdown banner for active user", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      refute html =~ "waitlist-countdown"
      refute html =~ "until you can start connecting"
    end

    test "profile shortcut links navigate to correct paths", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(active_user())
        |> live(~p"/my")

      assert has_element?(lv, "a[href='/my/settings/profile/photo']")
      assert has_element?(lv, "a[href='/my/settings/profile/traits']")
      assert has_element?(lv, "a[href='/my/settings/profile/moodboard']")
      assert has_element?(lv, "a[href='/my/settings/account']")
      assert has_element?(lv, "a[href='/my/settings/blocked-contacts']")
    end
  end

  describe "My Hub page — waitlisted user" do
    test "shows greeting with user display name", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "Hey #{user.display_name}!"
    end

    test "shows waitlist status banner inline", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "on the waitlist"
      assert html =~ "until you can start connecting"
    end

    test "renders countdown hook with data attributes", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "phx-hook=\"WaitlistCountdown\""
      assert html =~ "data-end-waitlist-at"
      assert html =~ "data-locale=\"en\""
    end

    test "shows processing text when end_waitlist_at is in the past", %{conn: conn} do
      user = user_fixture(language: "en")

      import Ecto.Query

      from(u in Animina.Accounts.User, where: u.id == ^user.id)
      |> Animina.Repo.update_all(
        set: [end_waitlist_at: DateTime.add(DateTime.utc_now(), -1, :day)]
      )

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "being processed"
    end

    test "shows preparation section inline", %{conn: conn} do
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

    test "shows original descriptions for incomplete cards", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "Upload your main profile photo."
      assert html =~ "Define what you&#39;re about and what you&#39;re looking for."
      assert html =~ "Add photos and stories to make a great first impression."
    end

    test "shows referral code inline", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ user.referral_code
      assert html =~ "Skip the waitlist"
    end

    test "shows referral count and threshold badge", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "Skip the waitlist"
      assert html =~ "0/"
      assert html =~ "reduces your waitlist time"
    end

    test "shows progress bar when user has referrals", %{conn: conn} do
      referrer = user_fixture(language: "en", display_name: "Referrer")
      _referred = user_fixture(language: "en", display_name: "Referred")

      import Ecto.Query

      from(u in Animina.Accounts.User, where: u.display_name == "Referred")
      |> Animina.Repo.update_all(set: [referred_by_id: referrer.id])

      {:ok, _lv, html} =
        conn
        |> log_in_user(referrer)
        |> live(~p"/my")

      assert html =~ "progress-accent"
      assert html =~ "1/"
    end

    test "still shows Settings and Logs cards", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert has_element?(lv, "main a[href='/my/settings']")
      assert has_element?(lv, "main a[href='/my/logs']")
    end

    test "hides Messages and Spotlight", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      refute has_element?(lv, "main a[href='/my/spotlight']")
      refute has_element?(lv, "main a[href='/my/messages']")
    end

    test "shows passkey card as optional when user has no passkeys", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ ~r"/my/settings/account"
      assert html =~ "Set up a passkey"
      assert html =~ "Optional"
    end

    test "shows passkey card with checkmark when user has passkeys", %{conn: conn} do
      user = user_fixture(language: "en")

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
        |> live(~p"/my")

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
        |> live(~p"/my")

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
        |> live(~p"/my")

      assert html =~ "2 flags set"
    end

    test "shows moodboard item count when user has moodboard items", %{conn: conn} do
      user = user_fixture(language: "en")

      story_moodboard_item_fixture(user, "My story")
      story_moodboard_item_fixture(user, "Another story", %{position: 1})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

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
        |> live(~p"/my")

      assert html =~ "1 contact blocked"
    end

    test "renders column toggle with default columns", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "change_columns"
    end

    test "change_columns event updates the card grid layout", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      # Switch to 2 columns
      html = lv |> element(~s|button[phx-value-columns="2"]|) |> render_click()
      assert html =~ "grid-cols-2"

      # Switch to 1 column
      html = lv |> element(~s|button[phx-value-columns="1"]|) |> render_click()
      assert html =~ "grid-cols-1"
    end

    test "has dynamic page title with days remaining", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      title = page_title(lv)
      assert title =~ "Waitlisted"
      assert title =~ "days left"
    end

    test "shows completion checkmarks on profile preparation cards", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      # Fresh user has incomplete items — should show empty circle indicators
      assert html =~ "border-base-content/20"
    end
  end

  describe "/my/waitlist redirect" do
    test "redirects /my/waitlist to /my", %{conn: conn} do
      user = user_fixture(language: "en")

      assert {:error, {:live_redirect, %{to: "/my"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/my/waitlist")
    end
  end
end
