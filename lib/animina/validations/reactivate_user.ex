defmodule Animina.Validations.ReactivateUser do
  use Ash.Resource.Validation
  alias Animina.Accounts.User
  alias Animina.Narratives.Story

  @moduledoc """
  This is a module for ensuring the user
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
    check_if_user_can_reactivate(changeset.action.name, changeset.data.id)
  end

  defp check_if_user_can_reactivate(:reactivate, user_id) do
    user = User.by_id!(user_id)

    if user_has_an_about_me_story_with_image?(user) && user.profile_photo != nil do
      :ok
    else
      {:error,
       field: :reactivate,
       message:
         "You cannot reactivate the user, because the user does not have an about me story with an image or a profile photo"}
    end
  end

  defp check_if_user_can_reactivate(_, _) do
    :ok
  end

  def user_has_an_about_me_story_with_image?(user) do
    case get_stories_for_a_user(user) do
      [] ->
        false

      stories ->
        stories
        |> Enum.find(fn story -> story.headline.subject == "About me" end)
        |> case do
          nil -> false
          story -> not is_nil(story.photo)
        end
    end
  end

  defp get_stories_for_a_user(user) do
    {:ok, stories} = Story.by_user_id(user.id)
    stories
  end
end
