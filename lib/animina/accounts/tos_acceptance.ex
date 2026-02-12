defmodule Animina.Accounts.TosAcceptance do
  @moduledoc """
  Schema for recording individual Terms of Service acceptance events.

  Each row captures who accepted which ToS version and when,
  providing a full audit trail of consent.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tos_acceptances" do
    belongs_to :user, User

    field :version, :string
    field :accepted_at, :utc_datetime
    field :inserted_at, :utc_datetime
  end

  def changeset(acceptance, attrs) do
    acceptance
    |> cast(attrs, [:user_id, :version, :accepted_at])
    |> validate_required([:user_id, :version, :accepted_at])
    |> foreign_key_constraint(:user_id)
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    if changeset.valid? && is_nil(get_field(changeset, :inserted_at)) do
      put_change(changeset, :inserted_at, DateTime.utc_now(:second))
    else
      changeset
    end
  end
end
