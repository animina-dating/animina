defmodule Animina.Checks.CreateMessageCheck do
  @moduledoc """
  Policy for The Message Resource
  """
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.Message
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User

  def describe(_opts) do
    "Check that the sender can only send messages to receivers who have preapproved communication as false and if they have it as true , the receiver has to have liked me as the sender. We also ensure the user cannot send messages to themselves"
  end

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    receiver = changeset.attributes.receiver_id |> User.by_id!()

    if receiver.preapproved_communication_only do
      receiver_has_liked_the_sender(receiver.id, actor.id)
    else
      if receiver.id == actor.id do
        false
      else
        check_messages_within_minutes(
          Message.messages_sent_to_a_user_by_sender!(actor.id, receiver.id),
          1,
          10
        ) &&
          check_messages_within_minutes(
            Message.messages_sent_by_user!(actor.id),
            1,
            20
          ) &&
          check_messages_within_minutes(
            Message.messages_sent_to_a_user_by_sender!(actor.id, receiver.id),
            60,
            50
          ) &&
          check_messages_within_minutes(
            Message.messages_sent_by_user!(actor.id),
            1440,
            250
          )
      end
    end
  end

  defp receiver_has_liked_the_sender(receiver_id, actor_id) do
    case Reaction.by_sender_and_receiver_id(receiver_id, actor_id) do
      {:ok, _reaction} ->
        if receiver_id == actor_id do
          false
        else
          true
        end

      {:error, _} ->
        false
    end
  end

  defp check_messages_within_minutes(messages, minutes, limit) do
    current_time = DateTime.utc_now()

    previous_time = DateTime.add(current_time, -minutes, :minute)

    messages =
      messages
      |> Enum.filter(fn message ->
        DateTime.compare(message.created_at, previous_time) == :gt and
          DateTime.compare(message.created_at, current_time) == :lt
      end)

    if Enum.count(messages) > limit do
      false
    else
      true
    end
  end
end
