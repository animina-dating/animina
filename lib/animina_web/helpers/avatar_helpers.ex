defmodule AniminaWeb.Helpers.AvatarHelpers do
  @moduledoc """
  Shared avatar photo loading helpers.
  """

  alias Animina.Photos

  @doc """
  Loads avatar photos for a list of user IDs.

  Returns a map of `%{user_id => photo}`, excluding users with no avatar.
  """
  def load_avatars(user_ids) do
    for uid <- Enum.uniq(user_ids),
        photo = Photos.get_user_avatar_any_state(uid),
        photo != nil,
        into: %{} do
      {uid, photo}
    end
  end

  @doc """
  Loads avatar photos for a list of conversations (keyed by other_user.id).
  """
  def load_from_conversations(conversations) do
    conversations
    |> Enum.map(& &1.other_user.id)
    |> load_avatars()
  end

  @doc """
  Loads avatar photos for a list of users (keyed by user.id).
  """
  def load_from_users(users) do
    users
    |> Enum.map(& &1.id)
    |> load_avatars()
  end
end
