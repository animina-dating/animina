defmodule Animina.Messaging.UnreadNotifier do
  @moduledoc """
  Background job that sends email notifications for unread messages.

  Runs hourly and notifies users who:
  - Have unread messages older than 24 hours
  - Haven't been notified in the last 24 hours

  This prevents spamming users while ensuring they eventually know about messages.
  """

  import Ecto.Query

  alias Animina.Accounts.{User, UserNotifier}
  alias Animina.Messaging
  alias Animina.Messaging.Schemas.{ConversationParticipant, Message}
  alias Animina.Repo
  alias Animina.TimeMachine

  require Logger

  @doc """
  Main entry point called by the Quantum scheduler.
  """
  def run do
    Logger.info("[UnreadNotifier] Starting unread message notification check")

    users = users_with_old_unread_messages()
    notified_count = Enum.count(users, &notify_user/1)

    Logger.info("[UnreadNotifier] Notified #{notified_count} users about unread messages")

    {:ok, notified_count}
  end

  @doc """
  Finds users who have unread messages older than 24 hours
  and haven't been notified in the last 24 hours.
  """
  def users_with_old_unread_messages do
    cutoff_24h_ago = TimeMachine.utc_now() |> DateTime.add(-24, :hour)

    # Find users with unread messages older than 24h
    User
    |> join(:inner, [u], cp in ConversationParticipant, on: cp.user_id == u.id)
    |> join(:inner, [u, cp], m in Message,
      on:
        m.conversation_id == cp.conversation_id and
          m.sender_id != u.id and
          is_nil(m.deleted_at)
    )
    |> where([u, cp, m], is_nil(u.deleted_at))
    |> where([u, cp, m], is_nil(cp.last_read_at) or cp.last_read_at < m.inserted_at)
    |> where([u, cp, m], m.inserted_at < ^cutoff_24h_ago)
    |> where(
      [u, cp, m],
      is_nil(u.last_message_notified_at) or u.last_message_notified_at < ^cutoff_24h_ago
    )
    |> select([u, cp, m], u.id)
    |> distinct(true)
    |> Repo.all()
    |> Enum.map(&Repo.get(User, &1))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Sends a notification email to a user about their unread messages.
  Updates the user's last_message_notified_at timestamp.
  """
  def notify_user(user) do
    unread_count = Messaging.unread_count(user.id)

    if unread_count > 0 do
      case UserNotifier.deliver_unread_messages_notification(
             user,
             unread_count
           ) do
        {:ok, _} ->
          update_notified_at(user)
          true

        {:error, reason} ->
          Logger.warning("[UnreadNotifier] Failed to notify user #{user.id}: #{inspect(reason)}")

          false
      end
    else
      false
    end
  end

  defp update_notified_at(user) do
    user
    |> Ecto.Changeset.change(last_message_notified_at: TimeMachine.utc_now(:second))
    |> Repo.update()
  end
end
