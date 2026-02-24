defmodule AniminaWeb.MessagesLiveWingmanTest do
  use AniminaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Messaging
  alias Animina.Wingman

  describe "wingman card in conversation" do
    setup do
      user1 = user_fixture(display_name: "Alice", language: "en")
      user2 = user_fixture(display_name: "Bob", language: "en")
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      %{user1: user1, user2: user2, conversation: conversation}
    end

    test "wingman card does not appear when feature flag is off", %{
      conn: conn,
      user1: user1,
      conversation: conversation
    } do
      # Feature flag is off by default
      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conversation.id}")

      refute html =~ "Wingman"
    end

    test "wingman card shows loading state when feature flag is on and no messages", %{
      conn: conn,
      user1: user1,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conversation.id}")

      # Should show loading state (pending generation) — no messages yet
      assert html =~ "Wingman"

      FunWithFlags.disable(:wingman)
    end

    test "wingman does not appear when conversation has messages", %{
      conn: conn,
      user1: user1,
      user2: user2,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      # Send a message first
      {:ok, _msg} = Messaging.send_message(conversation.id, user2.id, "Hello!")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conversation.id}")

      # Should NOT show wingman since there are already messages
      refute html =~ "Wingman is thinking"

      FunWithFlags.disable(:wingman)
    end

    test "dismiss_wingman hides the card", %{
      conn: conn,
      user1: user1,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conversation.id}")

      # Dismiss the wingman
      lv |> element("button[phx-click=dismiss_wingman]") |> render_click()

      html = render(lv)
      refute html =~ "Wingman is thinking"

      FunWithFlags.disable(:wingman)
    end

    test "wingman card shows suggestions when broadcast received", %{
      conn: conn,
      user1: user1,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conversation.id}")

      # Simulate wingman suggestions arriving via PubSub
      suggestions = [
        %{"text" => "Ask about her hiking photos!", "hook" => "Shows genuine interest"},
        %{"text" => "You both love cooking", "hook" => "Shared interest"}
      ]

      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        Wingman.suggestion_topic(conversation.id, user1.id),
        {:wingman_ready, suggestions}
      )

      # Wait for PubSub
      :timer.sleep(50)
      html = render(lv)

      assert html =~ "Ask about her hiking photos!"
      assert html =~ "Shows genuine interest"
      assert html =~ "You both love cooking"

      FunWithFlags.disable(:wingman)
    end

    test "wingman disappears after first message is sent", %{
      conn: conn,
      user1: user1,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user1)
        |> live(~p"/my/messages/#{conversation.id}")

      # Simulate wingman suggestions arriving
      suggestions = [%{"text" => "Try asking about cooking", "hook" => "Shared interest"}]

      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        Wingman.suggestion_topic(conversation.id, user1.id),
        {:wingman_ready, suggestions}
      )

      :timer.sleep(50)
      html = render(lv)
      assert html =~ "Try asking about cooking"

      # Send a message
      lv
      |> form("#message-form", %{message: %{content: "Hey, do you like cooking?"}})
      |> render_submit()

      :timer.sleep(50)
      html = render(lv)

      # Wingman should be gone after first message
      refute html =~ "Try asking about cooking"
      refute html =~ "Wingman is thinking"

      FunWithFlags.disable(:wingman)
    end
  end
end
