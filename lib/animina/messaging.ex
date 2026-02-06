defmodule Animina.Messaging do
  @moduledoc """
  Context for 1:1 messaging between users.

  This module provides the public API for:
  - Creating and listing conversations
  - Sending, editing, and deleting messages
  - Read receipts and unread counts
  - Blocking within conversations
  - Real-time PubSub broadcasting
  """

  import Ecto.Query

  alias Animina.Messaging.Schemas.{Conversation, ConversationParticipant, Message}
  alias Animina.Repo

  # --- PubSub Topics ---

  @doc """
  Returns the PubSub topic for a user's message notifications.
  """
  def user_topic(user_id), do: "messages:user:#{user_id}"

  @doc """
  Returns the PubSub topic for a conversation.
  """
  def conversation_topic(conversation_id), do: "conversation:#{conversation_id}"

  @doc """
  Returns the PubSub topic for typing indicators in a conversation.
  """
  def typing_topic(conversation_id), do: "typing:#{conversation_id}"

  # --- Conversations ---

  @doc """
  Gets or creates a conversation between two users.

  Returns `{:ok, conversation}` or `{:error, reason}`.
  """
  def get_or_create_conversation(user1_id, user2_id) do
    if user1_id == user2_id do
      {:error, :cannot_message_self}
    else
      case find_conversation(user1_id, user2_id) do
        nil -> create_conversation(user1_id, user2_id)
        conversation -> {:ok, conversation}
      end
    end
  end

  @doc """
  Finds an existing conversation between two users without creating one.

  Returns the conversation or nil.
  """
  def find_existing_conversation(user1_id, user2_id), do: find_conversation(user1_id, user2_id)

  defp find_conversation(user1_id, user2_id) do
    Conversation
    |> join(:inner, [c], p1 in ConversationParticipant,
      on: p1.conversation_id == c.id and p1.user_id == ^user1_id
    )
    |> join(:inner, [c, _p1], p2 in ConversationParticipant,
      on: p2.conversation_id == c.id and p2.user_id == ^user2_id
    )
    |> Repo.one()
  end

  defp create_conversation(user1_id, user2_id) do
    Repo.transaction(fn ->
      {:ok, conversation} =
        %Conversation{}
        |> Conversation.changeset(%{})
        |> Repo.insert()

      {:ok, _} =
        %ConversationParticipant{}
        |> ConversationParticipant.changeset(%{
          conversation_id: conversation.id,
          user_id: user1_id
        })
        |> Repo.insert()

      {:ok, _} =
        %ConversationParticipant{}
        |> ConversationParticipant.changeset(%{
          conversation_id: conversation.id,
          user_id: user2_id
        })
        |> Repo.insert()

      conversation
    end)
  end

  @doc """
  Lists all conversations for a user, ordered by most recent message.

  Each conversation includes the other participant and the latest message.
  """
  def list_conversations(user_id) do
    subquery =
      from m in Message,
        where: is_nil(m.deleted_at),
        group_by: m.conversation_id,
        select: %{
          conversation_id: m.conversation_id,
          last_message_at: max(m.inserted_at)
        }

    Conversation
    |> join(:inner, [c], p in ConversationParticipant,
      on: p.conversation_id == c.id and p.user_id == ^user_id
    )
    |> join(:left, [c, _p], latest in subquery(subquery), on: latest.conversation_id == c.id)
    |> order_by([c, _p, latest], desc_nulls_last: latest.last_message_at, desc: c.inserted_at)
    |> preload([c, _p, _latest], [:participants])
    |> Repo.all()
    |> Enum.map(&load_conversation_details(&1, user_id))
  end

  defp load_conversation_details(conversation, user_id) do
    other_participant =
      Enum.find(conversation.participants, fn p -> p.user_id != user_id end)

    other_user =
      if other_participant do
        Animina.Accounts.get_user(other_participant.user_id)
      end

    latest_message =
      Message
      |> where([m], m.conversation_id == ^conversation.id)
      |> where([m], is_nil(m.deleted_at))
      |> order_by([m], desc: m.inserted_at)
      |> limit(1)
      |> Repo.one()

    my_participant = Enum.find(conversation.participants, fn p -> p.user_id == user_id end)

    unread =
      if my_participant && latest_message && latest_message.sender_id != user_id do
        is_nil(my_participant.last_read_at) ||
          DateTime.compare(my_participant.last_read_at, latest_message.inserted_at) == :lt
      else
        false
      end

    %{
      conversation: conversation,
      other_user: other_user,
      latest_message: latest_message,
      unread: unread,
      blocked: other_participant && other_participant.blocked_at != nil,
      draft_content: my_participant && my_participant.draft_content
    }
  end

  @doc """
  Gets a conversation by ID.
  """
  def get_conversation(id) do
    Conversation
    |> Repo.get(id)
    |> Repo.preload(:participants)
  end

  @doc """
  Gets a conversation with the other participant loaded.
  """
  def get_conversation_for_user(conversation_id, user_id) do
    case get_conversation(conversation_id) do
      nil ->
        nil

      conversation ->
        if participant?(conversation_id, user_id) do
          load_conversation_details(conversation, user_id)
        else
          nil
        end
    end
  end

  # --- Messages ---

  @doc """
  Sends a message in a conversation.

  Returns `{:ok, message}` or `{:error, reason}`.
  Broadcasts the message to PubSub topics.
  """
  def send_message(conversation_id, sender_id, content) do
    cond do
      !participant?(conversation_id, sender_id) ->
        {:error, :not_participant}

      blocked_in_conversation?(conversation_id, sender_id) ->
        {:error, :blocked}

      true ->
        attrs = %{
          conversation_id: conversation_id,
          sender_id: sender_id,
          content: content
        }

        case %Message{}
             |> Message.changeset(attrs)
             |> Repo.insert() do
          {:ok, message} ->
            message = Repo.preload(message, :sender)
            clear_draft(conversation_id, sender_id)
            broadcast_new_message(conversation_id, message)
            {:ok, message}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Edits a message if it hasn't been read by the recipient.

  Returns `{:ok, message}` or `{:error, reason}`.
  """
  def edit_message(message_id, user_id, new_content) do
    with {:ok, message} <- get_message_for_user(message_id, user_id),
         :ok <- verify_sender(message, user_id),
         :ok <- verify_not_read(message) do
      message
      |> Message.edit_changeset(new_content)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          broadcast_message_edited(message.conversation_id, updated)
          {:ok, updated}

        error ->
          error
      end
    end
  end

  @doc """
  Soft-deletes a message if it hasn't been read by the recipient.

  Returns `{:ok, message}` or `{:error, reason}`.
  """
  def delete_message(message_id, user_id) do
    with {:ok, message} <- get_message_for_user(message_id, user_id),
         :ok <- verify_sender(message, user_id),
         :ok <- verify_not_read(message),
         {:ok, deleted} <- message |> Message.delete_changeset() |> Repo.update() do
      broadcast_message_deleted(message.conversation_id, deleted)

      recipient_id = get_other_participant_id(message.conversation_id, message.sender_id)
      if recipient_id, do: broadcast_unread_count_changed(recipient_id)

      {:ok, deleted}
    end
  end

  defp get_message_for_user(message_id, _user_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  defp verify_sender(message, user_id) do
    if message.sender_id == user_id do
      :ok
    else
      {:error, :not_sender}
    end
  end

  defp verify_not_read(message) do
    other_read_at =
      ConversationParticipant
      |> where([p], p.conversation_id == ^message.conversation_id)
      |> where([p], p.user_id != ^message.sender_id)
      |> select([p], p.last_read_at)
      |> Repo.one()

    if other_read_at != nil and DateTime.compare(other_read_at, message.inserted_at) != :lt do
      {:error, :already_read}
    else
      :ok
    end
  end

  @doc """
  Lists messages in a conversation for a user.

  Options:
  - `:limit` - Maximum number of messages (default: 50)
  - `:before` - Only messages before this datetime
  """
  def list_messages(conversation_id, user_id, opts \\ []) do
    if participant?(conversation_id, user_id) do
      limit = Keyword.get(opts, :limit, 50)
      before = Keyword.get(opts, :before)

      query =
        Message
        |> where([m], m.conversation_id == ^conversation_id)
        |> where([m], is_nil(m.deleted_at))
        |> order_by([m], asc: m.inserted_at)
        |> limit(^limit)
        |> preload(:sender)

      query =
        if before do
          where(query, [m], m.inserted_at < ^before)
        else
          query
        end

      Repo.all(query)
    else
      []
    end
  end

  # --- Read Receipts ---

  @doc """
  Marks a conversation as read for a user.
  """
  def mark_as_read(conversation_id, user_id) do
    case get_participant(conversation_id, user_id) do
      nil ->
        {:error, :not_participant}

      participant ->
        participant
        |> ConversationParticipant.mark_read_changeset()
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            broadcast_read_receipt(conversation_id, user_id)
            broadcast_unread_count_changed(user_id)
            {:ok, updated}

          error ->
            error
        end
    end
  end

  @doc """
  Returns the count of conversations with unread messages for a user.
  """
  def unread_count(user_id) do
    ConversationParticipant
    |> join(:inner, [p], c in Conversation, on: p.conversation_id == c.id)
    |> join(:inner, [p, c], m in Message,
      on:
        m.conversation_id == c.id and
          m.sender_id != ^user_id and
          is_nil(m.deleted_at)
    )
    |> where([p, _c, _m], p.user_id == ^user_id)
    |> where([p, _c, m], is_nil(p.last_read_at) or p.last_read_at < m.inserted_at)
    |> select([p, _c, _m], count(p.conversation_id, :distinct))
    |> Repo.one()
  end

  @doc """
  Returns the other participant's `last_read_at` timestamp.

  Used to display read receipts — the caller can compare this against
  their own messages' `inserted_at` to know which messages have been seen.
  """
  def get_other_participant_last_read(conversation_id, user_id) do
    ConversationParticipant
    |> where([p], p.conversation_id == ^conversation_id)
    |> where([p], p.user_id != ^user_id)
    |> select([p], p.last_read_at)
    |> Repo.one()
  end

  # --- Blocking ---

  @doc """
  Blocks a user in a conversation.

  The blocker's participant record gets blocked_at set. This prevents
  the other user from sending messages.
  """
  def block_in_conversation(conversation_id, blocker_id) do
    case get_participant(conversation_id, blocker_id) do
      nil ->
        {:error, :not_participant}

      participant ->
        participant
        |> ConversationParticipant.block_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Unblocks a user in a conversation.
  """
  def unblock_in_conversation(conversation_id, user_id) do
    case get_participant(conversation_id, user_id) do
      nil ->
        {:error, :not_participant}

      participant ->
        participant
        |> ConversationParticipant.unblock_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Checks if a user is blocked from sending messages in a conversation.

  Returns true if the OTHER participant has blocked.
  """
  def blocked_in_conversation?(conversation_id, user_id) do
    # Check if the other participant has blocked
    ConversationParticipant
    |> where([p], p.conversation_id == ^conversation_id)
    |> where([p], p.user_id != ^user_id)
    |> where([p], not is_nil(p.blocked_at))
    |> Repo.exists?()
  end

  # --- Drafts ---

  @doc """
  Saves a draft message for a user in a conversation.

  Sets content and timestamp, or clears both if content is empty/nil.
  """
  def save_draft(conversation_id, user_id, content) do
    case get_participant(conversation_id, user_id) do
      nil ->
        {:error, :not_participant}

      participant ->
        participant
        |> ConversationParticipant.draft_changeset(content)
        |> Repo.update()
    end
  end

  @doc """
  Gets the draft content and timestamp for a user in a conversation.

  Returns `{content, updated_at}` or `{nil, nil}` if no draft.
  """
  def get_draft(conversation_id, user_id) do
    case get_participant(conversation_id, user_id) do
      nil -> {nil, nil}
      %{draft_content: nil} -> {nil, nil}
      %{draft_content: content, draft_updated_at: updated_at} -> {content, updated_at}
    end
  end

  @doc """
  Clears the draft for a user in a conversation.
  """
  def clear_draft(conversation_id, user_id) do
    save_draft(conversation_id, user_id, nil)
  end

  # --- Helpers ---

  defp participant?(conversation_id, user_id) do
    ConversationParticipant
    |> where([p], p.conversation_id == ^conversation_id and p.user_id == ^user_id)
    |> Repo.exists?()
  end

  defp get_participant(conversation_id, user_id) do
    ConversationParticipant
    |> where([p], p.conversation_id == ^conversation_id and p.user_id == ^user_id)
    |> Repo.one()
  end

  defp get_other_participant_id(conversation_id, user_id) do
    ConversationParticipant
    |> where([p], p.conversation_id == ^conversation_id and p.user_id != ^user_id)
    |> select([p], p.user_id)
    |> Repo.one()
  end

  # --- PubSub Broadcasting ---

  defp broadcast_new_message(conversation_id, message) do
    # Broadcast to conversation topic
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      conversation_topic(conversation_id),
      {:new_message, message}
    )

    # Broadcast to all participants' user topics
    ConversationParticipant
    |> where([p], p.conversation_id == ^conversation_id)
    |> select([p], p.user_id)
    |> Repo.all()
    |> Enum.each(fn user_id ->
      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        user_topic(user_id),
        {:new_message, conversation_id, message}
      )
    end)
  end

  defp broadcast_message_edited(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      conversation_topic(conversation_id),
      {:message_edited, message}
    )
  end

  defp broadcast_message_deleted(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      conversation_topic(conversation_id),
      {:message_deleted, message}
    )
  end

  defp broadcast_read_receipt(conversation_id, user_id) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      conversation_topic(conversation_id),
      {:read_receipt, user_id}
    )
  end

  defp broadcast_unread_count_changed(user_id) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      user_topic(user_id),
      {:unread_count_changed, unread_count(user_id)}
    )
  end

  @doc """
  Broadcasts a typing indicator.
  """
  def broadcast_typing(conversation_id, user_id, typing?) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      typing_topic(conversation_id),
      {:typing, user_id, typing?}
    )
  end

  # --- Discovery Integration ---

  @doc """
  Checks if a user can initiate a conversation with another user.

  This integrates with the discovery system - only users who appear
  in each other's discovery lists can initiate conversations.
  """
  def can_initiate_conversation?(initiator_id, target_id) do
    # For now, allow all conversations between different users.
    # Future: integrate with Discovery.generate_suggestions to check mutual visibility.
    initiator_id != target_id
  end

  @doc """
  Returns a MapSet of candidate_ids that have a conversation with the given user.
  Efficient batch query for the discover page.
  """
  def conversation_user_ids(user_id, candidate_ids) do
    ConversationParticipant
    |> join(:inner, [p1], p2 in ConversationParticipant,
      on: p1.conversation_id == p2.conversation_id and p2.user_id == ^user_id
    )
    |> where([p1, _p2], p1.user_id in ^candidate_ids)
    |> select([p1, _p2], p1.user_id)
    |> distinct(true)
    |> Repo.all()
    |> MapSet.new()
  end
end
