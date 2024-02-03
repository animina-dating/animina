defmodule AniminaWeb.Registration do
  @moduledoc """
  Functions for registration and user management.
  """
  alias Animina.Accounts

  def get_current_user(session) do
    case get_user_id(session) do
      nil ->
        nil

      user_id ->
        case Accounts.BasicUser.by_id(user_id) do
          {:ok, user} ->
            user

          _ ->
            nil
        end
    end
  end

  defp get_user_id(session) do
    case session["user"] do
      nil ->
        nil

      "" ->
        nil

      user_id ->
        user_id
        |> String.split("=")
        |> List.last()
    end
  end
end
