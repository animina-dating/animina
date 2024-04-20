defmodule Animina.Checks.CreateReactionCheck do
  @moduledoc """
  Policy for The Reaction Resource
  """
  alias Animina.Accounts.User
  use Ash.Policy.SimpleCheck

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
