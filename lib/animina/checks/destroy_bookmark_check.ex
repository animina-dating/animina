defmodule Animina.Checks.DestroyBookmarkCheck do
  @moduledoc """
  Policy for The Bookmark Resource
  """

  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Check if a user can delete a bookmark"
  end

  def match?(actor, params, _opts) do
    cond do
      params.changeset.data.reason == :visited && actor.id != params.changeset.data.owner_id ->
        false

      actor.id != params.changeset.data.owner_id ->
        true

      true ->
        false
    end
  end
end
