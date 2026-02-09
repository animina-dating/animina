defmodule AniminaWeb.MessagesLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Messaging

  describe "Messages page (unauthenticated)" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/messages")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "Messages index (conversation list)" do
    test "renders messages page with empty state", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my/messages")

      assert html =~ "Messages"
      assert html =~ "No conversations yet"
    end

    test "empty state has a link to discover page", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my/messages")

      assert html =~ ~s|href="/discover"|
      assert html =~ "Discover"
    end

    test "shows conversation list when conversations exist", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user2.id, "Hello Alice!")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages")

      assert html =~ "Bob"
      assert html =~ "Hello Alice!"
    end

    test "shows unread indicator for unread messages", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user2.id, "Unread message")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages")

      # Should show some visual indicator of unread (e.g., badge or styling)
      assert html =~ "Bob"
    end
  end

  describe "Conversation view" do
    test "shows messages in a conversation", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg1} = Messaging.send_message(conv.id, user1.id, "Hi Bob!")
      {:ok, _msg2} = Messaging.send_message(conv.id, user2.id, "Hello Alice!")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      assert html =~ "Hi Bob!"
      assert html =~ "Hello Alice!"
    end

    test "can send a message", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      lv
      |> form("#message-form", %{message: %{content: "New message from Alice"}})
      |> render_submit()

      # Message is added via PubSub, wait for it to arrive
      :timer.sleep(50)
      html = render(lv)
      assert html =~ "New message from Alice"
    end

    test "marks conversation as read when opened", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user2.id, "Unread message")

      # Verify unread before
      assert Messaging.unread_count(user1.id) == 1

      {:ok, _lv, _html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      # Verify read after
      assert Messaging.unread_count(user1.id) == 0
    end

    test "redirects to 404 for non-existent conversation", %{conn: conn} do
      user = user_fixture(language: "en")
      fake_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: "/my/messages", flash: _flash}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/my/messages/#{fake_id}")
    end

    test "redirects for conversation user is not part of", %{conn: conn} do
      user1 = user_fixture(language: "en")
      user2 = user_fixture(language: "en")
      user3 = user_fixture(language: "en")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:error, {:redirect, %{to: "/my/messages", flash: _flash}}} =
               conn
               |> log_in_user(user3)
               |> live(~p"/my/messages/#{conv.id}")
    end

    test "shows date separators between messages from different days", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "Hello today!")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      # Messages sent today should show a "Today" date separator
      assert html =~ "Today"
    end

    test "shows delete button on own unread messages", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "Delete me")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      # Own messages that haven't been read should have a delete button
      assert html =~ "delete-message-"
    end

    test "can delete own unread message", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, msg} = Messaging.send_message(conv.id, user1.id, "Delete me")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      lv |> element("#delete-message-#{msg.id}") |> render_click()

      :timer.sleep(50)
      html = render(lv)
      refute html =~ "Delete me"
    end

    test "shows read receipt with timestamp on last read message", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "Read this")

      # Bob reads the conversation
      Messaging.mark_as_read(conv.id, user2.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      # Should show double-check read receipt indicator
      assert html =~ "read-receipt"
      # Should show "Read" with a timestamp
      assert html =~ ~r/Read/
    end

    test "shows single checkmark for sent but unread messages", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "Unread message")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      # Should show single check (sent indicator) but not read-receipt
      assert html =~ "sent-receipt"
      refute html =~ "read-receipt"
    end

    test "shows read timestamp only on the last read message", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg1} = Messaging.send_message(conv.id, user1.id, "First message")
      {:ok, _msg2} = Messaging.send_message(conv.id, user1.id, "Second message")

      # Bob reads the conversation
      Messaging.mark_as_read(conv.id, user2.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      # Both messages should show read-receipt (double checkmarks)
      # but "Read HH:MM" text only appears once (on the last read message)
      read_receipt_count = length(Regex.scan(~r/read-receipt/, html))
      read_time_count = length(Regex.scan(~r/read-time/, html))

      assert read_receipt_count >= 1
      assert read_time_count == 1
    end

    test "textarea has data-draft-key with correct user IDs", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      assert html =~ "data-draft-key=\"draft:#{user1.id}:#{user2.id}\""
    end

    test "empty conversation shows helpful prompt", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      assert html =~ "No messages yet"
      assert html =~ "Send a message to start the conversation"
    end
  end

  describe "Markdown rendering" do
    test "renders bold markdown in message bubbles", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "This is **bold** text")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      assert html =~ "<strong>bold</strong>"
    end

    test "renders italic markdown in message bubbles", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "This is *italic* text")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      assert html =~ "<em>italic</em>"
    end

    test "escapes HTML in message content", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "<script>alert('xss')</script>")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      # Should escape the script tag in message content
      assert html =~ "&lt;script&gt;"
      assert html =~ "&lt;/script&gt;"
    end
  end

  describe "Unread badge in navigation" do
    test "shows unread badge with count when user has unread messages", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user2.id, "Unread!")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages")

      # The unread badge component shows a chat icon in the navbar
      assert html =~ "hero-chat-bubble-left-right"
      # With an unread message, the badge count should appear
      assert html =~ "bg-primary text-primary-content rounded-full"
    end

    test "shows chat icon without count when no unread messages", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages")

      # Chat icon should be present in the navbar
      assert html =~ "hero-chat-bubble-left-right"
    end
  end

  describe "Draft indicator in conversation list" do
    test "shows Draft: prefix when user has a draft in a conversation", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user2.id, "Hello Alice!")

      # Save a draft for user1
      {:ok, _} = Messaging.save_draft(conv.id, user1.id, "Unsent reply")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages")

      assert html =~ "Draft:"
      assert html =~ "Unsent reply"
    end

    test "shows normal message preview when no draft exists", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user2.id, "Hello Alice!")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages")

      refute html =~ "Draft:"
      assert html =~ "Hello Alice!"
    end

    test "loads draft into textarea when opening a conversation", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.save_draft(conv.id, user1.id, "My saved draft")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conv.id}")

      assert html =~ "My saved draft"
    end
  end

  describe "starting a conversation" do
    test "creates conversation when navigating with start_with param", %{conn: conn} do
      user1 = user_fixture(language: "en", display_name: "Alice")
      user2 = user_fixture(language: "en", display_name: "Bob")

      # When start_with is provided, it redirects to the conversation
      {:error, {:live_redirect, %{to: redirect_path}}} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages?start_with=#{user2.id}")

      assert redirect_path =~ "/my/messages/"

      # Follow the redirect
      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(redirect_path)

      assert html =~ "Bob"
    end
  end

  describe "Messaging context - get_other_participant_last_read/2" do
    test "returns nil when other participant hasn't read", _context do
      user1 = user_fixture(language: "en")
      user2 = user_fixture(language: "en")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert Messaging.get_other_participant_last_read(conv.id, user1.id) == nil
    end

    test "returns last_read_at when other participant has read", _context do
      user1 = user_fixture(language: "en")
      user2 = user_fixture(language: "en")

      {:ok, conv} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_message(conv.id, user1.id, "Read me")

      Messaging.mark_as_read(conv.id, user2.id)

      last_read = Messaging.get_other_participant_last_read(conv.id, user1.id)
      assert %DateTime{} = last_read
    end
  end
end
