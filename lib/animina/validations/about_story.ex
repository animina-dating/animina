defmodule Animina.Validations.AboutStory do
  use Ash.Resource.Validation
  alias Animina.Narratives.Headline

  alias Animina.Narratives.Story

  @moduledoc """
  This is a module for validating the first story is 'About me'
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

    user_id = Ash.Changeset.get_attribute(changeset, opts[:user])

    stories = get_stories_for_user(user_id)

    case Headline.by_id(headline_id) do
      {:ok, headline} ->
        if stories == [] && headline.subject != "About me" do
          {:error, field: opts[:attribute], message: "The first story must be 'About me'."}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  def get_stories_for_user(user_id) do
    Story
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.for_read(:read)
    |> Ash.read!()
  end
end
