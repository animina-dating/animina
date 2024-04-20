defmodule Animina.Checks.CreateMessageCheck do
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.User
  alias Animina.Accounts.Reaction

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
        true
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
end
