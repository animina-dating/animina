defmodule AniminaWeb.ChatPanelComponentTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.MessagingFixtures

  alias Animina.Messaging

  describe "chat panel on moodboard" do
    test "non-owner sees Message button", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      assert html =~ "Message"
    end

    test "owner does not see Message button", %{conn: conn} do
      owner = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(owner)
        |> live(~p"/moodboard/#{owner.id}")

      # The Message button uses toggle_chat; owner should not have it
      refute html =~ "toggle_chat"
    end

    test "clicking Message opens chat panel", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      html = lv |> element("button", "Message") |> render_click()

      assert html =~ "chat-panel"
      assert html =~ "Send a message to start the conversation"
    end

    test "toggling chat off hides the panel", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      # Open the chat
      lv |> element("button", "Message") |> render_click()

      # Toggle off by clicking the Message button again
      html = lv |> element("button", "Message") |> render_click()

      # Panel should be in closed state (translate-x-full)
      assert html =~ "translate-x-full"
      refute html =~ "translate-x-0"
    end

    test "close button in panel header closes the chat", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      # Open the chat
      lv |> element("button", "Message") |> render_click()

      # Close via the X button in the panel header
      lv
      |> element("#chat-panel button[aria-label=Close]")
      |> render_click()

      # Parent processes :close_chat_panel — re-render to see updated state
      html = render(lv)

      # Panel should be in closed state
      assert html =~ "translate-x-full"
    end

    test "chat panel starts below navbar (top-16) on all screen sizes", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      html = lv |> element("button", "Message") |> render_click()

      # Panel inner div should have top-16 (not lg:top-16) so it's always below the navbar
      assert html =~ "top-16 right-0 bottom-0"
    end

    test "sending first message creates conversation lazily", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      # Verify no conversation exists
      assert is_nil(Messaging.find_existing_conversation(visitor.id, owner.id))

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      # Open panel
      lv |> element("button", "Message") |> render_click()

      # Send a message
      lv
      |> form("#chat-panel-form", message: %{content: "Hello from moodboard!"})
      |> render_submit()

      # Conversation should now exist
      conversation = Messaging.find_existing_conversation(visitor.id, owner.id)
      assert conversation != nil
    end

    test "panel shows existing messages when conversation exists", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      # Create conversation with messages
      conversation = conversation_fixture(visitor, owner)
      _msg = message_fixture(conversation, visitor, %{content: "Pre-existing message"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      # Open panel
      html = lv |> element("button", "Message") |> render_click()

      assert html =~ "Pre-existing message"
    end

    test "textarea has data-draft-key with correct user IDs", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      html = lv |> element("button", "Message") |> render_click()

      assert html =~ "data-draft-key=\"draft:#{visitor.id}:#{owner.id}\""
    end

    test "panel shows link to full messages page", %{conn: conn} do
      owner = user_fixture(language: "en")
      visitor = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(visitor)
        |> live(~p"/moodboard/#{owner.id}")

      html = lv |> element("button", "Message") |> render_click()

      # Should have a link to full messages
      assert html =~ "hero-arrow-top-right-on-square"
    end
  end
end
