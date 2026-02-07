defmodule Animina.Accounts.UserPasskey do
  @moduledoc """
  Schema for WebAuthn/passkey credentials.

  Stores the credential_id and COSE public key returned by the authenticator
  during registration. The public_key is stored as an Erlang term (binary)
  because COSE keys are maps with integer keys that don't map cleanly to JSON.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_passkeys" do
    field :credential_id, :binary
    field :public_key, Animina.Accounts.CoseKeyType
    field :sign_count, :integer, default: 0
    field :label, :string
    field :last_used_at, :utc_datetime_usec

    belongs_to :user, Animina.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(passkey, attrs) do
    passkey
    |> cast(attrs, [:credential_id, :public_key, :sign_count, :label, :last_used_at, :user_id])
    |> validate_required([:credential_id, :public_key, :user_id])
    |> validate_length(:label, max: 100)
    |> unique_constraint(:credential_id)
    |> foreign_key_constraint(:user_id)
  end
end
