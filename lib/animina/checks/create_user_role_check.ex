defmodule Animina.Checks.CreateUserRoleCheck do
  @moduledoc """
  Policy for The Checking that only a user with the admin role can add a user to the admin role group
  """

  alias Animina.Accounts.Role
  alias Animina.Accounts.UserRole
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Checks that only a user with the admin role can add a user to the admin role group"
  end

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do

    IO.inspect("I also pass here")
    role = Role.by_id!(changeset.attributes.role_id)

    user_roles = UserRole.by_user_id!(actor.id)

    case role do
      nil ->
        false

      _ ->
        if role.name == :admin do
          user_an_admin?(user_roles)
        else
          true
        end
    end


  end

  defp user_an_admin?([]) do
    false
  end

  defp user_an_admin?(user_roles) do
    user_roles
    |> Enum.map(fn user_role -> user_role.role.name end)
    |> Enum.any?(fn role -> role == :admin end)
  end
end
