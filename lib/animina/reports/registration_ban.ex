defmodule Animina.Reports.RegistrationBan do
  @moduledoc """
  Schema for registration bans.

  All values are SHA-256 hashes — no plaintext phone numbers or emails stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_ban_types ~w(phone email)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "registration_bans" do
    belongs_to :report, Animina.Reports.Report

    field :ban_type, :string
    field :hash_value, :string
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:ban_type, :hash_value, :report_id, :notes])
    |> validate_required([:ban_type, :hash_value, :report_id])
    |> validate_inclusion(:ban_type, @valid_ban_types)
    |> foreign_key_constraint(:report_id)
    |> unique_constraint([:ban_type, :hash_value])
  end
end
