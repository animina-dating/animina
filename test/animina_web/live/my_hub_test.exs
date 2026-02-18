defmodule AniminaWeb.MyHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures
  import Animina.TraitsFixtures

  alias Animina.Messaging
  alias Animina.Traits

  defp set_user_normal(user) do
    user
    |> Ecto.Changeset.change(state: "normal")
    |> Animina.Repo.update!()
  end

  describe "MyHub (unauthenticated)" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "Hub mode (incomplete profile)" do
    test "shows hub cards when profile is incomplete", %{conn: conn} do
      # Default user_fixture has 3/6 items (height, location, partner prefs)
      # and state: "waitlisted" — hub mode shows Settings/Logs regardless
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      # Should see hub navigation cards
      assert html =~ "Settings"
      assert html =~ "Logs"
      # Should see profile progress bar
      assert html =~ "Profile progress"
    end

    test "shows Messages and Spotlight hub cards for non-waitlisted incomplete user", %{
      conn: conn
    } do
      user = user_fixture(language: "en") |> set_user_normal()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      assert html =~ "Messages"
      assert html =~ "Spotlight"
    end
  end

  describe "Dashboard mode (complete profile)" do
    setup do
      user = user_fixture(language: "en", display_name: "DashUser") |> set_user_normal()

      # Add approved avatar photo (item 4/6)
      _photo =
        approved_photo_fixture(%{
          owner_id: user.id,
          owner_type: "User",
          type: "avatar"
        })

      # Add a flag (item 5/6) — need a category first
      flag = flag_fixture()

      {:ok, _user_flag} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          position: 1
        })

      # Now user has 5/6 items: height, location, partner_prefs, photo, flags
      # Missing: moodboard (need 2 items)
      %{user: user}
    end

    test "shows dashboard with spotlight section", %{conn: conn, user: user} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      # Should show dashboard greeting
      assert html =~ "Hey DashUser!"
      # Should show spotlight section
      assert html =~ "Daily Spotlight"
      # Should NOT show Settings/Logs hub cards
      refute html =~ "Your account activity logs"
    end

    test "shows unread conversations when messages exist", %{conn: conn, user: user} do
      other = user_fixture(language: "en", display_name: "ChatPartner")

      {:ok, conv} = Messaging.get_or_create_conversation(user.id, other.id)
      {:ok, _msg} = Messaging.send_message(conv.id, other.id, "Hey there!")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      # Should show unread section
      assert html =~ "ChatPartner"
      assert html =~ "Hey there!"
    end

    test "shows conversations summary when no unread messages", %{conn: conn, user: user} do
      other = user_fixture(language: "en", display_name: "ReadUser")

      {:ok, conv} = Messaging.get_or_create_conversation(user.id, other.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user.id, "I sent this")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      # Should show the conversations summary link
      assert html =~ "All messages"
    end

    test "clicking a conversation opens the chat panel", %{conn: conn, user: user} do
      other = user_fixture(language: "en", display_name: "PanelUser")

      {:ok, conv} = Messaging.get_or_create_conversation(user.id, other.id)
      {:ok, _msg} = Messaging.send_message(conv.id, other.id, "Open me!")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my")

      html =
        lv
        |> element("[phx-click=open_chat][phx-value-conversation-id=\"#{conv.id}\"]")
        |> render_click()

      # Chat panel should now be visible
      assert html =~ "PanelUser"
    end
  end
end
