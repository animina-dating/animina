defmodule Animina.Checks.CreateVisitLogEntryCheck do
  @moduledoc """
  Policy for The VisitLog Resource
  """

  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.Bookmark

  def describe(_opts) do
    "Check a user cannot create a visit log entry for a bookmark they do not own"
  end

  def match?(actor, params, _opts) do
    if actor.id == get_owner_for_bookmark(params.changeset.attributes.bookmark_id) do
      true
    else
      false
    end
  end

  defp get_owner_for_bookmark(nil) do
     nil
  end

  defp get_owner_for_bookmark(id) do
    case Bookmark.by_id(id) do
      {:ok, bookmark} -> bookmark.owner_id
      _ -> nil
    end
  end
end
