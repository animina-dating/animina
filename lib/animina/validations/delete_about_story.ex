defmodule Animina.Validations.DeleteAboutStory do
  use Ash.Resource.Validation
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  @moduledoc """
  This is a module for ensuring the 'About me' story is not
  deleted at all
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
    headline_id =
      Ash.Changeset.get_attribute(changeset, opts[:headline])

    case Headline.by_id(headline_id) do
      {:ok, headline} ->
        if headline.subject == "About me" do
          {:error, field: opts[:attribute], message: "You cannot delete the 'About me' story."}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  defp get_stories_for_user(user_id) do
    Story.read!()
    |> Enum.filter(fn story -> story.user_id == user_id end)
  end
end
