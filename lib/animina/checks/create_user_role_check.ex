defmodule Animina.Checks.CreateUserRoleCheck do
  @moduledoc """
  Policy for The Checking that only a user with the admin role can add a user to the admin role group
  """
  alias Animina.Accounts.User
  alias Animina.Accounts.Role
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Checks that only a user with the admin role can add a user to the admin role group"
  end

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    role = Role.by_id!(changeset.attributes.role_id)

    case role do
      nil ->
        false

      _ ->
        if role.name == :admin do
          is_user_an_admin?(actor.roles)
        else
          true
        end
    end
  end

  defp is_user_an_admin?([]) do
    false
  end

  defp is_user_an_admin?(roles) do
    roles
    |> Enum.map(fn role -> role.name end)
    |> Enum.any?(fn role -> role == :admin end)
  end
end
