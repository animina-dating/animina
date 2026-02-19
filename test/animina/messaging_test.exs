defmodule Animina.MessagingTest do
  use Animina.DataCase, async: true

  import Ecto.Query

  alias Animina.AccountsFixtures
  alias Animina.Messaging
  alias Animina.Messaging.Schemas.{Conversation, Message}

  describe "get_or_create_conversation/2" do
    test "creates a new conversation between two users" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      assert {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      assert %Conversation{} = conversation
      assert conversation.id != nil
    end

    test "returns existing conversation if it exists" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      {:ok, conversation1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, conversation2} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert conversation1.id == conversation2.id
    end

    test "returns same conversation regardless of user order" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      {:ok, conversation1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, conversation2} = Messaging.get_or_create_conversation(user2.id, user1.id)

      assert conversation1.id == conversation2.id
    end

    test "does not allow conversation with self" do
      user = AccountsFixtures.user_fixture()

      assert {:error, :cannot_message_self} =
               Messaging.get_or_create_conversation(user.id, user.id)
    end
  end

  describe "send_message/3" do
    test "sends a message in a conversation" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:ok, message} = Messaging.send_message(conversation.id, user1.id, "Hello!")
      assert %Message{} = message
      assert message.content == "Hello!"
      assert message.sender_id == user1.id
      assert message.conversation_id == conversation.id
    end

    test "fails with empty content" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:error, changeset} = Messaging.send_message(conversation.id, user1.id, "")
      assert "can't be blank" in errors_on(changeset).content
    end

    test "fails if sender is not a participant" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:error, :not_participant} =
               Messaging.send_message(conversation.id, user3.id, "Hello!")
    end

    test "fails if sender is blocked" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.block_in_conversation(conversation.id, user2.id)

      assert {:error, :blocked} = Messaging.send_message(conversation.id, user1.id, "Hello!")
    end
  end

  describe "edit_message/3" do
    test "edits a message before it's read" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "Original")

      assert {:ok, edited} = Messaging.edit_message(message.id, user1.id, "Edited")
      assert edited.content == "Edited"
      assert edited.edited_at != nil
    end

    test "cannot edit someone else's message" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "Original")

      assert {:error, :not_sender} = Messaging.edit_message(message.id, user2.id, "Edited")
    end

    test "cannot edit message after recipient has read it" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "Original")
      {:ok, _} = Messaging.mark_as_read(conversation.id, user2.id)

      assert {:error, :already_read} = Messaging.edit_message(message.id, user1.id, "Edited")
    end
  end

  describe "delete_message/2" do
    test "soft deletes a message before it's read and within 15 minutes" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "To delete")

      assert {:ok, deleted} = Messaging.delete_message(message.id, user1.id)
      assert deleted.deleted_at != nil
    end

    test "cannot delete someone else's message" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "To delete")

      assert {:error, :not_sender} = Messaging.delete_message(message.id, user2.id)
    end

    test "cannot delete message after recipient has read it" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "To delete")
      {:ok, _} = Messaging.mark_as_read(conversation.id, user2.id)

      assert {:error, :already_read} = Messaging.delete_message(message.id, user1.id)
    end

    test "cannot delete message after 15-minute window expires" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "Old message")

      # Backdate message to 16 minutes ago
      Animina.Repo.update_all(
        from(m in Messaging.Schemas.Message, where: m.id == ^message.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -16, :minute)]
      )

      assert {:error, :delete_window_expired} = Messaging.delete_message(message.id, user1.id)
    end

    test "cannot delete message when other user is online" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "To delete")

      # Track the other user as online
      AniminaWeb.Presence.track_user(self(), user2.id)

      assert {:error, :other_user_online} = Messaging.delete_message(message.id, user1.id)
    end

    test "cannot delete message when other user was online since it was sent" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      # Backdate message to 5 minutes ago
      {:ok, message} = Messaging.send_message(conversation.id, user1.id, "To delete")

      Animina.Repo.update_all(
        from(m in Message, where: m.id == ^message.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -5, :minute)]
      )

      # Create an online session for user2 that started after the message was sent
      # (simulates them having been online 2 minutes ago but now offline)
      Animina.Repo.insert!(%Animina.Accounts.UserOnlineSession{
        user_id: user2.id,
        started_at: DateTime.add(DateTime.utc_now(), -3, :minute) |> DateTime.truncate(:second),
        ended_at: DateTime.add(DateTime.utc_now(), -2, :minute) |> DateTime.truncate(:second),
        duration_minutes: 1
      })

      assert {:error, :other_user_online} = Messaging.delete_message(message.id, user1.id)
    end
  end

  describe "list_messages/3" do
    test "lists messages in a conversation" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.send_message(conversation.id, user1.id, "Message 1")
      {:ok, _} = Messaging.send_message(conversation.id, user2.id, "Message 2")

      messages = Messaging.list_messages(conversation.id, user1.id)
      assert length(messages) == 2
    end

    test "does not list deleted messages" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, msg1} = Messaging.send_message(conversation.id, user1.id, "Message 1")
      {:ok, _} = Messaging.send_message(conversation.id, user2.id, "Message 2")
      {:ok, _} = Messaging.delete_message(msg1.id, user1.id)

      messages = Messaging.list_messages(conversation.id, user1.id)
      assert length(messages) == 1
    end

    test "returns empty list for non-participant" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.send_message(conversation.id, user1.id, "Message")

      messages = Messaging.list_messages(conversation.id, user3.id)
      assert messages == []
    end
  end

  describe "list_conversations/1" do
    test "lists user's conversations with latest message" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, conv1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.send_message(conv1.id, user1.id, "Hello user2")

      {:ok, conv2} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, _} = Messaging.send_message(conv2.id, user3.id, "Hello user1")

      conversations = Messaging.list_conversations(user1.id)
      assert length(conversations) == 2
    end

    test "orders by most recent message" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, conv1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _msg1} = Messaging.send_message(conv1.id, user1.id, "Old message")

      # Ensure different timestamps by waiting over a second
      Process.sleep(1100)

      {:ok, conv2} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, _msg2} = Messaging.send_message(conv2.id, user3.id, "New message")

      conversations = Messaging.list_conversations(user1.id)
      [first, second] = conversations
      assert first.conversation.id == conv2.id
      assert second.conversation.id == conv1.id
    end
  end

  describe "mark_as_read/2" do
    test "marks conversation as read for user" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.send_message(conversation.id, user1.id, "Message")

      assert Messaging.unread_count(user2.id) == 1
      {:ok, _} = Messaging.mark_as_read(conversation.id, user2.id)
      assert Messaging.unread_count(user2.id) == 0
    end
  end

  describe "unread_count/1" do
    test "counts conversations with unread messages" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, conv1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.send_message(conv1.id, user2.id, "From user2")

      {:ok, conv2} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, _} = Messaging.send_message(conv2.id, user3.id, "From user3")

      assert Messaging.unread_count(user1.id) == 2
    end

    test "does not count own sent messages as unread" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.send_message(conversation.id, user1.id, "I sent this")

      assert Messaging.unread_count(user1.id) == 0
    end
  end

  describe "block_in_conversation/2" do
    test "blocks a user in a conversation" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:ok, participant} = Messaging.block_in_conversation(conversation.id, user1.id)
      assert participant.blocked_at != nil
    end
  end

  describe "unblock_in_conversation/2" do
    test "unblocks a user in a conversation" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.block_in_conversation(conversation.id, user1.id)

      assert {:ok, participant} = Messaging.unblock_in_conversation(conversation.id, user1.id)
      assert participant.blocked_at == nil
    end
  end

  describe "conversation_user_ids/2" do
    test "returns user IDs that have conversations with the given user" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()
      user4 = AccountsFixtures.user_fixture()

      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user3.id)

      result = Messaging.conversation_user_ids(user1.id, [user2.id, user3.id, user4.id])

      assert MapSet.member?(result, user2.id)
      assert MapSet.member?(result, user3.id)
      refute MapSet.member?(result, user4.id)
    end

    test "returns empty set when no conversations exist" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      result = Messaging.conversation_user_ids(user1.id, [user2.id])
      assert MapSet.size(result) == 0
    end

    test "returns empty set for empty candidate list" do
      user1 = AccountsFixtures.user_fixture()
      result = Messaging.conversation_user_ids(user1.id, [])
      assert MapSet.size(result) == 0
    end
  end

  describe "save_draft/3" do
    test "saves a draft for a user in a conversation" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:ok, participant} =
               Messaging.save_draft(conversation.id, user1.id, "Hello, this is a draft")

      assert participant.draft_content == "Hello, this is a draft"
      assert participant.draft_updated_at != nil
    end

    test "overwrites an existing draft" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.save_draft(conversation.id, user1.id, "First draft")
      {:ok, participant} = Messaging.save_draft(conversation.id, user1.id, "Updated draft")

      assert participant.draft_content == "Updated draft"
    end

    test "clears draft when content is empty" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.save_draft(conversation.id, user1.id, "Some draft")
      {:ok, participant} = Messaging.save_draft(conversation.id, user1.id, "")

      assert participant.draft_content == nil
      assert participant.draft_updated_at == nil
    end

    test "clears draft when content is nil" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.save_draft(conversation.id, user1.id, "Some draft")
      {:ok, participant} = Messaging.save_draft(conversation.id, user1.id, nil)

      assert participant.draft_content == nil
      assert participant.draft_updated_at == nil
    end
  end

  describe "get_draft/2" do
    test "returns draft content and timestamp" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.save_draft(conversation.id, user1.id, "My draft")

      {content, updated_at} = Messaging.get_draft(conversation.id, user1.id)
      assert content == "My draft"
      assert %DateTime{} = updated_at
    end

    test "returns {nil, nil} when no draft exists" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {nil, nil} = Messaging.get_draft(conversation.id, user1.id)
    end
  end

  describe "clear_draft/2" do
    test "clears an existing draft" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.save_draft(conversation.id, user1.id, "Draft to clear")
      {:ok, participant} = Messaging.clear_draft(conversation.id, user1.id)

      assert participant.draft_content == nil
      assert participant.draft_updated_at == nil
    end
  end

  describe "draft cleared on send_message" do
    test "sending a message clears the sender's draft" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.save_draft(conversation.id, user1.id, "Draft before send")
      {:ok, _message} = Messaging.send_message(conversation.id, user1.id, "Actual message")

      {content, updated_at} = Messaging.get_draft(conversation.id, user1.id)
      assert content == nil
      assert updated_at == nil
    end
  end

  describe "draft in list_conversations" do
    test "includes draft_content in conversation details" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.save_draft(conversation.id, user1.id, "Unsent draft")

      conversations = Messaging.list_conversations(user1.id)
      conv_detail = Enum.find(conversations, &(&1.conversation.id == conversation.id))

      assert conv_detail.draft_content == "Unsent draft"
    end

    test "draft_content is nil when no draft exists" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      conversations = Messaging.list_conversations(user1.id)
      conv_detail = Enum.find(conversations, &(&1.conversation.id == conversation.id))

      assert conv_detail.draft_content == nil
    end
  end

  describe "blocked_in_conversation?/2" do
    test "returns true if user is blocked" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.block_in_conversation(conversation.id, user2.id)

      assert Messaging.blocked_in_conversation?(conversation.id, user1.id) == true
    end

    test "returns false if user is not blocked" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert Messaging.blocked_in_conversation?(conversation.id, user1.id) == false
    end
  end

  # --- Chat Slot System Tests ---

  describe "active_conversation_count/1" do
    test "counts open (non-closed) conversations" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user3.id)

      assert Messaging.active_conversation_count(user1.id) == 2
    end

    test "does not count closed conversations" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, conv1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, _} = Messaging.close_conversation(conv1.id, user1.id)

      assert Messaging.active_conversation_count(user1.id) == 1
    end

    test "returns 0 when user has no conversations" do
      user1 = AccountsFixtures.user_fixture()
      assert Messaging.active_conversation_count(user1.id) == 0
    end
  end

  describe "has_available_chat_slot?/1" do
    test "returns true when under limit" do
      user1 = AccountsFixtures.user_fixture()
      assert Messaging.has_available_chat_slot?(user1.id) == true
    end
  end

  describe "daily_new_chat_count/1" do
    test "counts conversations initiated today by the user" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert Messaging.daily_new_chat_count(user1.id) == 1
    end

    test "does not count conversations initiated by others" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      # user2 initiates, so user1's count should be 0
      {:ok, _} = Messaging.get_or_create_conversation(user2.id, user1.id)

      assert Messaging.daily_new_chat_count(user1.id) == 0
    end
  end

  describe "can_start_new_chat_today?/1" do
    test "returns true when under daily limit" do
      user1 = AccountsFixtures.user_fixture()
      assert Messaging.can_start_new_chat_today?(user1.id) == true
    end
  end

  describe "close_conversation/2" do
    test "closes a conversation for both participants" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:ok, _} = Messaging.close_conversation(conversation.id, user1.id)

      # Both participants should have closed_at set
      conversations = Messaging.list_conversations(user1.id)
      assert conversations == []

      conversations = Messaging.list_conversations(user2.id)
      assert conversations == []
    end

    test "creates closure records" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      assert {:ok, _} = Messaging.close_conversation(conversation.id, user1.id)

      # Should be able to list closed conversations
      closed = Messaging.list_closed_conversations(user1.id)
      assert length(closed) == 1
    end

    test "creates bidirectional dismissal records" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

      {:ok, _} = Messaging.close_conversation(conversation.id, user1.id)

      # Both directions should be dismissed
      assert Animina.Discovery.dismissed?(user1.id, user2.id)
      assert Animina.Discovery.dismissed?(user2.id, user1.id)
    end
  end

  describe "list_closed_conversations/1" do
    test "returns closed conversations for a user" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.close_conversation(conversation.id, user1.id)

      closed = Messaging.list_closed_conversations(user1.id)
      assert length(closed) == 1
      assert hd(closed).conversation_id == conversation.id
    end

    test "does not return reopened conversations" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()
      user4 = AccountsFixtures.user_fixture()
      user5 = AccountsFixtures.user_fixture()
      user6 = AccountsFixtures.user_fixture()

      {:ok, conv_reopen} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, conv_close1} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, conv_close2} = Messaging.get_or_create_conversation(user1.id, user4.id)
      {:ok, conv_close3} = Messaging.get_or_create_conversation(user1.id, user5.id)
      {:ok, conv_close4} = Messaging.get_or_create_conversation(user1.id, user6.id)

      {:ok, _} = Messaging.close_conversation(conv_reopen.id, user1.id)

      {:ok, _} =
        Messaging.love_emergency_reopen(user1.id, conv_reopen.id, [
          conv_close1.id,
          conv_close2.id,
          conv_close3.id,
          conv_close4.id
        ])

      closed = Messaging.list_closed_conversations(user1.id)
      conv_ids = Enum.map(closed, & &1.conversation_id)
      refute conv_reopen.id in conv_ids
    end
  end

  describe "chat_slot_status/1" do
    test "returns slot status map" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user2.id)

      status = Messaging.chat_slot_status(user1.id)
      assert status.active == 1
      assert status.max >= 1
      assert status.daily_started == 1
      assert status.daily_max >= 1
    end
  end

  describe "can_initiate_conversation?/2" do
    test "returns :ok when user can initiate" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      assert :ok = Messaging.can_initiate_conversation?(user1.id, user2.id)
    end

    test "returns error for self-messaging" do
      user1 = AccountsFixtures.user_fixture()

      assert {:error, :cannot_message_self} =
               Messaging.can_initiate_conversation?(user1.id, user1.id)
    end

    test "returns error when conversation was previously closed" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.close_conversation(conversation.id, user1.id)

      assert {:error, :previously_closed} =
               Messaging.can_initiate_conversation?(user1.id, user2.id)
    end
  end

  describe "list_conversations/1 excludes closed" do
    test "closed conversations are excluded from the list" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, conv1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, _} = Messaging.close_conversation(conv1.id, user1.id)

      conversations = Messaging.list_conversations(user1.id)
      assert length(conversations) == 1
      assert hd(conversations).conversation.id != conv1.id
    end
  end

  describe "conversation_user_ids/2 excludes closed" do
    test "closed conversation partners are excluded" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, conv1} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, _} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, _} = Messaging.close_conversation(conv1.id, user1.id)

      result = Messaging.conversation_user_ids(user1.id, [user2.id, user3.id])
      refute MapSet.member?(result, user2.id)
      assert MapSet.member?(result, user3.id)
    end
  end

  describe "love_emergency_reopen/3" do
    test "reopens a closed conversation and closes others" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()
      user4 = AccountsFixtures.user_fixture()
      user5 = AccountsFixtures.user_fixture()
      user6 = AccountsFixtures.user_fixture()

      {:ok, conv_reopen} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, conv_close1} = Messaging.get_or_create_conversation(user1.id, user3.id)
      {:ok, conv_close2} = Messaging.get_or_create_conversation(user1.id, user4.id)
      {:ok, conv_close3} = Messaging.get_or_create_conversation(user1.id, user5.id)
      {:ok, conv_close4} = Messaging.get_or_create_conversation(user1.id, user6.id)

      {:ok, _} = Messaging.close_conversation(conv_reopen.id, user1.id)

      assert {:ok, _} =
               Messaging.love_emergency_reopen(user1.id, conv_reopen.id, [
                 conv_close1.id,
                 conv_close2.id,
                 conv_close3.id,
                 conv_close4.id
               ])

      # Reopened conversation should be active
      conversations = Messaging.list_conversations(user1.id)
      conv_ids = Enum.map(conversations, & &1.conversation.id)
      assert conv_reopen.id in conv_ids

      # Closed conversations should not be active
      refute conv_close1.id in conv_ids
      refute conv_close2.id in conv_ids
      refute conv_close3.id in conv_ids
      refute conv_close4.id in conv_ids
    end

    test "fails with wrong number of conversations to close" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      {:ok, conv_reopen} = Messaging.get_or_create_conversation(user1.id, user2.id)
      {:ok, conv_close1} = Messaging.get_or_create_conversation(user1.id, user3.id)

      {:ok, _} = Messaging.close_conversation(conv_reopen.id, user1.id)

      assert {:error, :wrong_cost} =
               Messaging.love_emergency_reopen(user1.id, conv_reopen.id, [conv_close1.id])
    end
  end
end
