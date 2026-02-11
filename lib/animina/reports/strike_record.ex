defmodule Animina.Reports.StrikeRecord do
  @moduledoc """
  Schema for persistent strike records keyed by phone hash.

  Strikes survive account deletion and follow users across re-registrations.
  Lookup is always by phone_hash (SHA-256).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "strike_records" do
    belongs_to :report, Animina.Reports.Report

    field :phone_hash, :string
    field :email_hash, :string
    field :resolution, :string
    field :category, :string
    field :resolved_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(strike, attrs) do
    strike
    |> cast(attrs, [:phone_hash, :email_hash, :report_id, :resolution, :category, :resolved_at])
    |> validate_required([
      :phone_hash,
      :email_hash,
      :report_id,
      :resolution,
      :category,
      :resolved_at
    ])
    |> foreign_key_constraint(:report_id)
  end
end
