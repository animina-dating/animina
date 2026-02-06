defmodule Animina.Discovery.Schemas.Dismissal do
  @moduledoc """
  Schema for permanent "Not interested" dismissals.
  Once a user dismisses another user, they will never appear in suggestions again.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_dismissals" do
    belongs_to :user, User
    belongs_to :dismissed, User

    timestamps(type: :utc_datetime)
  end

  def changeset(dismissal, attrs) do
    dismissal
    |> cast(attrs, [:user_id, :dismissed_id])
    |> validate_required([:user_id, :dismissed_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:dismissed_id)
    |> unique_constraint([:user_id, :dismissed_id])
  end
end
