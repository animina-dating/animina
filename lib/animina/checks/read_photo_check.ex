defmodule Animina.Checks.ReadPhotoCheck do
  @moduledoc """
  Policy for The Read Action for a Photo
  """
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.User

  def describe(_opts) do
    "Ensures an actor can only read photos if they are from a public account if the actor is nil"
  end

  def match?(actor, params, _opts) do
    if actor do
      true
    else
      if params.query.arguments != %{} and params.query.arguments.user_id != nil do
        check_if_user_is_public(params.query.arguments.user_id)
      else
        false
      end
    end
  end

  defp check_if_user_is_public(user_id) do
    user = User.by_id!(user_id)

    if user.public do
      true
    else
      false
    end
  end
end
