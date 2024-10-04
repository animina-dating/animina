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
  def validate(changeset, opts, _context) do
    if changeset.data.story_id do
      check_if_story_is_about_me(changeset, opts)
    else
      :ok
    end
  end

  defp check_if_story_is_about_me(changeset, opts) do
    case Story.by_id_with_headline(changeset.data.story_id) do
      {:ok, story} ->
        if story.headline.subject == "About me" do
          {:error, field: opts[:attribute], message: "The About me story must have a photo."}
        else
          :ok
        end

      _ ->
        :ok
    end
  end
end
