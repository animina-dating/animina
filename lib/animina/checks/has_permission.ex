defmodule Animina.Checks.ActorHasPermission do
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.User
  alias Animina.Accounts.Reaction

  def describe(_opts) do
    "Check that the sender can only send messages to receivers who have preapproved communication as false and if they have it as true , the receiver has to have liked me as the sender"
  end

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    receiver = changeset.attributes.receiver_id |> User.by_id!()

    if receiver_has_preapproved_communication_only(receiver) do
      receiver_has_liked_the_sender(changeset.attributes.sender_id, receiver.id)
    else
      true
    end

    actor.preapproved_communication_only == true
  end

  defp receiver_has_preapproved_communication_only(receiver) do
    receiver.preapproved_communication_only
  end

  defp receiver_has_liked_the_sender(sender_id, receiver_id) do
    case Reaction.by_sender_and_receiver_id(sender_id, receiver_id) do
      {:ok, reaction} ->
        reaction

      {:error, _} ->
        nil
    end
  end
end
