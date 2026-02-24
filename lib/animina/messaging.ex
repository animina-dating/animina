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

  require Logger

  alias Animina.ActivityLog
  alias Animina.Discovery
  alias Animina.FeatureFlags
  alias Animina.Relationships
  alias Animina.TimeMachine

  alias Animina.Messaging.Schemas.{
    Conversation,
    ConversationClosure,
    ConversationParticipant,
    Message
  }

  alias Animina.Repo
  alias Animina.Utils.Timezone

  # Messages can only be deleted within 15 minutes of creation
  @delete_window_seconds 15 * 60

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
  def get_conversation_by_participants(user1_id, user2_id),
    do: find_conversation(user1_id, user2_id)

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
      with {:ok, conversation} <-
             %Conversation{} |> Conversation.changeset(%{}) |> Repo.insert(),
           {:ok, _} <-
             %ConversationParticipant{}
             |> ConversationParticipant.changeset(%{
               conversation_id: conversation.id,
               user_id: user1_id,
               initiator: true
             })
             |> Repo.insert(),
           {:ok, _} <-
             %ConversationParticipant{}
             |> ConversationParticipant.changeset(%{
               conversation_id: conversation.id,
               user_id: user2_id
             })
             |> Repo.insert() do
        # Create a "chatting" relationship between the two users
        Relationships.create_relationship(user1_id, user2_id, "chatting")

        conversation
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Lists all conversations for a user, ordered by most recent message.

  Each conversation includes the other participant and the latest message.
  """
  def list_conversations(user_id) do
    last_message_subquery =
      from m in Message,
        where: is_nil(m.deleted_at),
        group_by: m.conversation_id,
        select: %{
          conversation_id: m.conversation_id,
          last_message_at: max(m.inserted_at)
        }

    conversations =
      Conversation
      |> join(:inner, [c], p in ConversationParticipant,
        on: p.conversation_id == c.id and p.user_id == ^user_id
      )
      |> where([_c, p], is_nil(p.closed_at))
      |> join(:left, [c, _p], latest in subquery(last_message_subquery),
        on: latest.conversation_id == c.id
      )
      |> order_by([c, _p, latest], desc_nulls_last: latest.last_message_at, desc: c.inserted_at)
      |> preload([c, _p, _latest], [:participants])
      |> Repo.all()

    if conversations == [] do
      []
    else
      conversation_ids = Enum.map(conversations, & &1.id)

      # Batch-load latest messages for all conversations (one query instead of N)
      latest_messages = batch_load_latest_messages(conversation_ids)

      # Batch-load other users (one query instead of N)
      other_user_ids =
        conversations
        |> Enum.flat_map(fn c ->
          c.participants
          |> Enum.filter(&(&1.user_id != user_id))
          |> Enum.map(& &1.user_id)
        end)
        |> Enum.uniq()

      users_by_id = batch_load_users(other_user_ids)

      Enum.map(conversations, fn conversation ->
        assemble_conversation_details(conversation, user_id, latest_messages, users_by_id)
      end)
    end
  end

  defp batch_load_latest_messages(conversation_ids) do
    # Use a window function to get the latest message per conversation
    ranked =
      from(m in Message,
        where: m.conversation_id in ^conversation_ids and is_nil(m.deleted_at),
        select: %{
          id: m.id,
          conversation_id: m.conversation_id,
          sender_id: m.sender_id,
          content: m.content,
          inserted_at: m.inserted_at,
          row_num:
            row_number()
            |> over(partition_by: m.conversation_id, order_by: [desc: m.inserted_at])
        }
      )

    from(r in subquery(ranked), where: r.row_num == 1)
    |> Repo.all()
    |> Map.new(&{&1.conversation_id, &1})
  end

  defp batch_load_users(user_ids) do
    Animina.Accounts.User
    |> where([u], u.id in ^user_ids)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp assemble_conversation_details(conversation, user_id, latest_messages, users_by_id) do
    other_participant = find_other_participant(conversation.participants, user_id)
    my_participant = find_my_participant(conversation.participants, user_id)

    other_user =
      if other_participant, do: Map.get(users_by_id, other_participant.user_id)

    latest_message = Map.get(latest_messages, conversation.id)

    %{
      conversation: conversation,
      other_user: other_user,
      latest_message: latest_message,
      unread: compute_unread(my_participant, latest_message, user_id),
      blocked: other_participant && other_participant.blocked_at != nil,
      draft_content: my_participant && my_participant.draft_content
    }
  end

  defp load_conversation_details(conversation, user_id) do
    other_participant = find_other_participant(conversation.participants, user_id)
    my_participant = find_my_participant(conversation.participants, user_id)

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

    %{
      conversation: conversation,
      other_user: other_user,
      latest_message: latest_message,
      unread: compute_unread(my_participant, latest_message, user_id),
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

            recipient_id = get_other_participant_id(conversation_id, sender_id)

            ActivityLog.log("social", "message_sent", "Message sent in conversation",
              actor_id: sender_id,
              subject_id: recipient_id,
              metadata: %{"conversation_id" => conversation_id}
            )

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
         :ok <- verify_within_delete_window(message),
         :ok <- verify_other_not_online(message),
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

  defp verify_within_delete_window(message) do
    age_seconds = DateTime.diff(TimeMachine.utc_now(), message.inserted_at, :second)

    if age_seconds <= @delete_window_seconds do
      :ok
    else
      {:error, :delete_window_expired}
    end
  end

  defp verify_other_not_online(message) do
    other_user_id = get_other_participant_id(message.conversation_id, message.sender_id)

    if other_user_id && other_was_online_since?(other_user_id, message.inserted_at) do
      {:error, :other_user_online}
    else
      :ok
    end
  end

  defp other_was_online_since?(user_id, since) do
    # Currently online via Presence
    # Or had a session overlapping with the window since the message was sent
    AniminaWeb.Presence.user_online?(user_id) ||
      Animina.Accounts.UserOnlineSession
      |> where([s], s.user_id == ^user_id)
      |> where([s], s.started_at <= ^TimeMachine.utc_now())
      |> where([s], is_nil(s.ended_at) or s.ended_at >= ^since)
      |> Repo.exists?()
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
  Returns the delete window duration in seconds.
  """
  def delete_window_seconds, do: @delete_window_seconds

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
        |> preload(:sender)

      query =
        if before do
          where(query, [m], m.inserted_at < ^before)
        else
          query
        end

      query
      |> order_by([m], asc: m.inserted_at)
      |> limit(^limit)
      |> Repo.all()
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
    |> where([p, _c, _m], is_nil(p.closed_at))
    |> where([p, _c, m], is_nil(p.last_read_at) or p.last_read_at < m.inserted_at)
    |> select([p, _c, _m], count(p.conversation_id, :distinct))
    |> Repo.one() || 0
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
        result =
          participant
          |> ConversationParticipant.block_changeset()
          |> Repo.update()

        if match?({:ok, _}, result),
          do: log_block_side_effects(conversation_id, blocker_id)

        result
    end
  end

  defp log_block_side_effects(conversation_id, blocker_id) do
    case handle_block_success(conversation_id, blocker_id) do
      {:error, reason} ->
        Logger.warning("[Messaging] Block side-effect failed: #{inspect(reason)}")

      _ ->
        :ok
    end
  end

  defp handle_block_success(conversation_id, blocker_id) do
    other_id = get_other_participant_id(conversation_id, blocker_id)

    result =
      case Relationships.get_relationship(blocker_id, other_id) do
        nil -> :ok
        rel -> Relationships.transition_status(rel, "blocked", blocker_id)
      end

    ActivityLog.log("social", "conversation_blocked", "User blocked in conversation",
      actor_id: blocker_id,
      subject_id: other_id,
      metadata: %{"conversation_id" => conversation_id}
    )

    result
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

  defp participant_query(conversation_id, user_id) do
    ConversationParticipant
    |> where([p], p.conversation_id == ^conversation_id and p.user_id == ^user_id)
  end

  defp participant?(conversation_id, user_id) do
    participant_query(conversation_id, user_id)
    |> Repo.exists?()
  end

  defp get_participant(conversation_id, user_id) do
    participant_query(conversation_id, user_id)
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

  Returns `:ok` or `{:error, reason}`.

  Checks:
  - Not self
  - Has available chat slot
  - No previously closed conversation between them
  """
  def can_initiate_conversation?(initiator_id, target_id) do
    cond do
      initiator_id == target_id ->
        {:error, :cannot_message_self}

      !has_available_chat_slot?(initiator_id) ->
        {:error, :chat_slots_full}

      has_closed_conversation?(initiator_id, target_id) ->
        {:error, :previously_closed}

      true ->
        :ok
    end
  end

  @doc """
  Returns a list of user IDs that the user has any non-blocked conversation with.
  """
  def list_conversation_partner_ids(user_id) do
    ConversationParticipant
    |> join(:inner, [p1], p2 in ConversationParticipant,
      on: p1.conversation_id == p2.conversation_id and p2.user_id != ^user_id
    )
    |> where([p1, _p2], p1.user_id == ^user_id)
    |> where([p1, _p2], is_nil(p1.blocked_at))
    |> select([_p1, p2], p2.user_id)
    |> distinct(true)
    |> Repo.all()
  end

  # --- Chat Slot System ---

  @doc """
  Returns the number of active (non-closed) conversations for a user.
  Only counts conversations that have at least one message.
  """
  def active_conversation_count(user_id) do
    ConversationParticipant
    |> where([p], p.user_id == ^user_id)
    |> where([p], is_nil(p.closed_at))
    |> where(
      [p],
      exists(
        from(m in Message,
          where: m.conversation_id == parent_as(:participant).conversation_id,
          select: 1
        )
      )
    )
    |> from(as: :participant)
    |> select([p], count(p.id))
    |> Repo.one()
  end

  @doc """
  Returns whether the user has a free chat slot.
  """
  def has_available_chat_slot?(user_id) do
    active_conversation_count(user_id) < FeatureFlags.chat_max_active_slots()
  end

  @doc """
  Returns the number of new conversations initiated by the user today (Berlin time).
  Only counts conversations that have at least one message.
  """
  def daily_new_chat_count(user_id) do
    {start_utc, end_utc} = Timezone.berlin_today_utc_range()

    ConversationParticipant
    |> where([p], p.user_id == ^user_id)
    |> where([p], p.initiator == true)
    |> where([p], p.inserted_at >= ^start_utc and p.inserted_at < ^end_utc)
    |> where(
      [p],
      exists(
        from(m in Message,
          where: m.conversation_id == parent_as(:participant).conversation_id,
          select: 1
        )
      )
    )
    |> from(as: :participant)
    |> select([p], count(p.id))
    |> Repo.one()
  end

  @doc """
  Returns whether the user can start a new chat today.
  """
  def can_start_new_chat_today?(user_id) do
    daily_new_chat_count(user_id) < FeatureFlags.chat_daily_new_limit()
  end

  @doc """
  Closes a conversation ("Let go"). Both participants' records are updated,
  closure records are created, and bidirectional dismissals are recorded.
  """
  def close_conversation(conversation_id, closed_by_id) do
    Repo.transaction(fn ->
      participants =
        ConversationParticipant
        |> where([p], p.conversation_id == ^conversation_id)
        |> Repo.all()

      other_participant = find_other_participant(participants, closed_by_id)
      my_participant = find_my_participant(participants, closed_by_id)

      if is_nil(my_participant) || is_nil(other_participant) do
        Repo.rollback(:not_participant)
      end

      # Close both participants
      {:ok, _} = my_participant |> ConversationParticipant.close_changeset() |> Repo.update()
      {:ok, _} = other_participant |> ConversationParticipant.close_changeset() |> Repo.update()

      # Create closure record (from the perspective of the closer)
      {:ok, _} =
        %ConversationClosure{}
        |> ConversationClosure.changeset(%{
          conversation_id: conversation_id,
          closed_by_id: closed_by_id,
          other_user_id: other_participant.user_id
        })
        |> Repo.insert()

      # Create bidirectional dismissals so they don't appear in each other's discovery
      Discovery.dismiss_user_by_id(closed_by_id, other_participant.user_id)
      Discovery.dismiss_user_by_id(other_participant.user_id, closed_by_id)

      # Transition relationship to "ended"
      case Relationships.get_relationship(closed_by_id, other_participant.user_id) do
        nil -> :ok
        rel -> Relationships.transition_status(rel, "ended", closed_by_id)
      end

      # Broadcast closure to both users
      broadcast_conversation_closed(conversation_id, closed_by_id, other_participant.user_id)

      ActivityLog.log("social", "conversation_closed", "Conversation closed",
        actor_id: closed_by_id,
        subject_id: other_participant.user_id,
        metadata: %{"conversation_id" => conversation_id}
      )

      :ok
    end)
  end

  @doc """
  Lists the last N closed conversations for a user (where reopened_at IS NULL).
  Returns closure records with the other user preloaded.
  """
  def list_closed_conversations(user_id, limit \\ 10) do
    ConversationClosure
    |> where([cc], cc.closed_by_id == ^user_id and is_nil(cc.reopened_at))
    |> order_by([cc], desc: cc.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(:other_user)
  end

  @doc """
  Reopens a closed conversation via Love Emergency.

  The user must close exactly `love_emergency_cost` active conversations to reopen one.
  """
  def love_emergency_reopen(user_id, reopen_conv_id, close_conv_ids) do
    cost = FeatureFlags.chat_love_emergency_cost()

    if length(close_conv_ids) != cost do
      {:error, :wrong_cost}
    else
      Repo.transaction(fn ->
        close_sacrificed_conversations(close_conv_ids, user_id)
        reopen_conversation_participants(reopen_conv_id, user_id)
        mark_closure_reopened(reopen_conv_id, user_id)
        broadcast_reopen(reopen_conv_id, user_id)
        :ok
      end)
    end
  end

  defp close_sacrificed_conversations(close_conv_ids, user_id) do
    Enum.each(close_conv_ids, fn conv_id ->
      case close_conversation(conv_id, user_id) do
        {:ok, _} -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp reopen_conversation_participants(conv_id, user_id) do
    participants =
      ConversationParticipant
      |> where([p], p.conversation_id == ^conv_id)
      |> Repo.all()

    Enum.each(participants, fn p ->
      {:ok, _} = p |> ConversationParticipant.reopen_changeset() |> Repo.update()
    end)

    # Reopen the relationship back to "chatting"
    other = find_other_participant(participants, user_id)

    if other do
      case Relationships.get_relationship(user_id, other.user_id) do
        nil ->
          Relationships.create_relationship(user_id, other.user_id, "chatting")

        %{status: status} = rel when status in ["ended", "blocked"] ->
          Relationships.reopen_relationship(rel, user_id)

        _rel ->
          :ok
      end
    end
  end

  defp mark_closure_reopened(conv_id, user_id) do
    closure =
      ConversationClosure
      |> where([cc], cc.conversation_id == ^conv_id and cc.closed_by_id == ^user_id)
      |> where([cc], is_nil(cc.reopened_at))
      |> Repo.one()

    if closure do
      {:ok, _} = closure |> ConversationClosure.reopen_changeset(user_id) |> Repo.update()
    end
  end

  defp broadcast_reopen(conv_id, user_id) do
    participants =
      ConversationParticipant
      |> where([p], p.conversation_id == ^conv_id)
      |> Repo.all()

    other = find_other_participant(participants, user_id)

    if other do
      broadcast_conversation_reopened(conv_id, user_id, other.user_id)

      ActivityLog.log(
        "social",
        "conversation_reopened",
        "Conversation reopened via Love Emergency",
        actor_id: user_id,
        subject_id: other.user_id,
        metadata: %{"conversation_id" => conv_id}
      )
    end
  end

  @doc """
  Returns a map with the user's current chat slot status.
  """
  def chat_slot_status(user_id) do
    %{
      active: active_conversation_count(user_id),
      max: FeatureFlags.chat_max_active_slots(),
      daily_started: daily_new_chat_count(user_id),
      daily_max: FeatureFlags.chat_daily_new_limit()
    }
  end

  @doc """
  Returns whether a closed conversation exists between two users.
  """
  def has_closed_conversation?(user1_id, user2_id) do
    ConversationClosure
    |> where(
      [cc],
      (cc.closed_by_id == ^user1_id and cc.other_user_id == ^user2_id) or
        (cc.closed_by_id == ^user2_id and cc.other_user_id == ^user1_id)
    )
    |> where([cc], is_nil(cc.reopened_at))
    |> Repo.exists?()
  end

  # --- Chat Slot PubSub ---

  defp broadcast_conversation_closed(conversation_id, closed_by_id, other_user_id) do
    Enum.each([closed_by_id, other_user_id], fn uid ->
      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        user_topic(uid),
        {:conversation_closed, conversation_id}
      )
    end)
  end

  defp broadcast_conversation_reopened(conversation_id, reopened_by_id, other_user_id) do
    Enum.each([reopened_by_id, other_user_id], fn uid ->
      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        user_topic(uid),
        {:conversation_reopened, conversation_id}
      )
    end)
  end

  # --- Participant helpers ---

  defp find_other_participant(participants, user_id) do
    Enum.find(participants, fn p -> p.user_id != user_id end)
  end

  defp find_my_participant(participants, user_id) do
    Enum.find(participants, fn p -> p.user_id == user_id end)
  end

  defp compute_unread(my_participant, latest_message, user_id) do
    if my_participant && latest_message && latest_message.sender_id != user_id do
      is_nil(my_participant.last_read_at) ||
        DateTime.compare(my_participant.last_read_at, latest_message.inserted_at) == :lt
    else
      false
    end
  end
end
