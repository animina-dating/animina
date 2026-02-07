defmodule AniminaWeb.Helpers.AvatarHelpers do
  @moduledoc """
  Shared avatar photo loading helpers.
  """

  alias Animina.Photos

  @doc """
  Loads avatar photos for a list of conversations (keyed by other_user.id).
  """
  def load_from_conversations(conversations) do
    for conv <- conversations,
        photo = Photos.get_user_avatar(conv.other_user.id),
        photo != nil,
        into: %{} do
      {conv.other_user.id, photo}
    end
  end

  @doc """
  Loads avatar photos for a list of users (keyed by user.id).
  """
  def load_from_users(users) do
    users
    |> Enum.map(fn user ->
      {user.id, Photos.get_user_avatar(user.id)}
    end)
    |> Enum.reject(fn {_id, photo} -> is_nil(photo) end)
    |> Map.new()
  end
end
