defmodule Animina.Checks.DestroyReactionCheck do
  @moduledoc """
  Policy for The Reaction Resource
  """

  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Check a user cannot delete a reaction to they did not create"
  end

  def match?(actor, params, _opts) do
    if actor.id == params.changeset.data.sender_id do
      true
    else
      false
    end
  end
end
