defmodule Animina.Checks.CreateMessageCheck do
  @moduledoc """
  Policy for The Message Resource
  """
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User

  def describe(_opts) do
    "Check that only the people who have sent the message can read it"
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
