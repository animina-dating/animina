defmodule Animina.Accounts.UserRole do
  @moduledoc """
  Schema for user role assignments.

  Only "moderator" and "admin" roles are stored in the database.
  The "user" role is implicit for everyone and never stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_roles ~w(moderator admin)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_roles" do
    belongs_to :user, Animina.Accounts.User
    field :role, :string

    timestamps(type: :utc_datetime)
  end

  def valid_roles, do: @valid_roles

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role])
    |> validate_required([:user_id, :role])
    |> validate_inclusion(:role, @valid_roles)
    |> unique_constraint([:user_id, :role])
    |> check_constraint(:role, name: :valid_role)
  end
end
