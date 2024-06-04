defmodule Animina.Checks.CreatePostCheck do
  @moduledoc """
  Policy for The Post Resource
  """
  alias Animina.Narratives
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Check a user cannot add a post if do not have at least 3 stories"
  end

  def match?(actor, %{changeset: %Ash.Changeset{} = _changeset}, _opts) do
    if Enum.count(fetch_stories(actor.id)) >= 3 do
      true
    else
      false
    end
  end

  defp fetch_stories(user_id) do
    stories =
      Narratives.Story
      |> Ash.Query.for_read(:by_user_id, %{user_id: user_id})
      |> Narratives.read!(page: [limit: 50])
      |> then(& &1.results)

    stories
  end
end
