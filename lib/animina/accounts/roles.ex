defmodule Animina.Accounts.Roles do
  @moduledoc """
  User role management functions.
  """

  import Ecto.Query

  alias Animina.Accounts.{User, UserRole}
  alias Animina.Repo
  alias Animina.Utils.PaperTrail, as: PT

  @doc """
  Returns all roles for the given user, always including the implicit "user" role.
  """
  def get_user_roles(%User{id: user_id}) do
    db_roles =
      from(r in UserRole, where: r.user_id == ^user_id, select: r.role)
      |> Repo.all()

    ["user" | db_roles]
  end

  @doc """
  Assigns a role to a user. Idempotent — does nothing if the role already exists.
  Returns `{:ok, user_role}` or `{:error, changeset}`.
  """
  def assign_role(%User{id: user_id}, role, opts \\ []) when role in ["moderator", "admin"] do
    case Repo.get_by(UserRole, user_id: user_id, role: role) do
      %UserRole{} = existing ->
        {:ok, existing}

      nil ->
        %UserRole{}
        |> UserRole.changeset(%{user_id: user_id, role: role})
        |> PaperTrail.insert(PT.opts(opts))
        |> PT.unwrap()
    end
  end

  @doc """
  Removes a role from a user. The implicit "user" role cannot be removed.
  Returns `{:ok, user_role}`, `{:error, :implicit_role}`, or `{:error, :not_found}`.
  """
  def remove_role(user, role, opts \\ [])

  def remove_role(_user, "user", _opts), do: {:error, :implicit_role}

  def remove_role(%User{id: user_id}, "admin", opts) do
    case Repo.get_by(UserRole, user_id: user_id, role: "admin") do
      nil ->
        {:error, :not_found}

      user_role ->
        admin_count = Repo.aggregate(from(r in UserRole, where: r.role == "admin"), :count)

        if admin_count <= 1 do
          {:error, :last_admin}
        else
          PaperTrail.delete(user_role, PT.opts(opts)) |> PT.unwrap()
        end
    end
  end

  def remove_role(%User{id: user_id}, role, opts) do
    case Repo.get_by(UserRole, user_id: user_id, role: role) do
      nil -> {:error, :not_found}
      user_role -> PaperTrail.delete(user_role, PT.opts(opts)) |> PT.unwrap()
    end
  end

  @doc """
  Returns true if the user has the given role.
  The "user" role is always true.
  """
  def has_role?(%User{}, "user"), do: true

  def has_role?(%User{id: user_id}, role) do
    from(r in UserRole, where: r.user_id == ^user_id and r.role == ^role)
    |> Repo.exists?()
  end

  @doc """
  Counts the number of users with a specific role.
  Only counts "moderator" and "admin" roles (not the implicit "user" role).
  """
  def count_users_with_role(role) when role in ["moderator", "admin"] do
    from(r in UserRole, where: r.role == ^role)
    |> Repo.aggregate(:count)
  end
end
