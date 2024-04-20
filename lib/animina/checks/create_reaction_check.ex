defmodule Animina.Checks.CreateReactionCheck do
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.User

  def describe(_opts) do
    "Check a user cannot add a reaction to their own profiles"
  end

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    receiver = changeset.attributes.receiver_id |> User.by_id!()

    if receiver.id == actor.id do
      false
    else
      true
    end
  end
end
