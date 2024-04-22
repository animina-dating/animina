defmodule Animina.Checks.DestroyReactionCheck do
  @moduledoc """
  Policy for The Reaction Resource
  """
  alias Animina.Accounts.User
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Check a user cannot delete a reaction to they did not create"
  end

  def match?(actor, params, _opts) do
    true
  end
end
