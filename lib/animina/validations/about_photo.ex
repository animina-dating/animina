defmodule Animina.Validations.AboutPhoto do
  use Ash.Resource.Validation
  alias Animina.Narratives.Story

  @moduledoc """
  This is a module for validating the 'About me' story has a photo
  """

  @impl true
  def init(opts) do
    case is_atom(opts[:attribute]) do
      true -> {:ok, opts}
      _ -> {:error, "attribute must be an atom!"}
    end
  end

  @impl true
  def validate(changeset, _opts, _context) do
    if changeset.data.story_id do
      :ok
    end
  end
end
