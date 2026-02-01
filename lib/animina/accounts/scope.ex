defmodule Animina.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Animina.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as the current role or other privileges for use as authorization, or to
  ensure specific code paths can only be accessed for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.
  """

  alias Animina.Accounts.User

  defstruct user: nil, current_role: "user", roles: ["user"]

  @doc """
  Creates a scope for the given user with default role ("user").

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope for the given user with roles loaded from the database.

  Validates that `current_role` is in the user's roles list.
  Falls back to "user" if the role is not valid.
  """
  def for_user(%User{} = user, roles, current_role) when is_list(roles) do
    validated_role =
      if current_role in roles do
        current_role
      else
        "user"
      end

    %__MODULE__{user: user, current_role: validated_role, roles: roles}
  end

  @doc """
  Returns true if the current role is "admin".
  """
  def admin?(%__MODULE__{current_role: "admin"}), do: true
  def admin?(_), do: false

  @doc """
  Returns true if the current role is "moderator" or "admin".
  Admins have moderator powers.
  """
  def moderator?(%__MODULE__{current_role: "admin"}), do: true
  def moderator?(%__MODULE__{current_role: "moderator"}), do: true
  def moderator?(_), do: false

  @doc """
  Returns true if the given role is in the scope's roles list.
  """
  def has_role?(%__MODULE__{roles: roles}, role), do: role in roles
  def has_role?(_, _), do: false

  @doc """
  Returns true if the scope has more than one role.
  """
  def has_multiple_roles?(%__MODULE__{roles: roles}), do: length(roles) > 1
  def has_multiple_roles?(_), do: false
end
