defmodule Animina.Reports.ReportInvisibility do
  @moduledoc """
  Schema for hash-based invisibility that survives account deletion.

  Each row represents one direction of invisibility. Two rows are created
  per report (user_a hidden from user_b, AND user_b hidden from user_a).

  Uses both user_id (fast lookup for active users) and phone_hash
  (persists after account deletion).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "report_invisibilities" do
    belongs_to :user, User
    belongs_to :hidden_user, User
    belongs_to :report, Animina.Reports.Report

    field :user_phone_hash, :string
    field :hidden_phone_hash, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(invisibility, attrs) do
    invisibility
    |> cast(attrs, [:user_id, :hidden_user_id, :user_phone_hash, :hidden_phone_hash, :report_id])
    |> validate_required([:user_phone_hash, :hidden_phone_hash, :report_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:hidden_user_id)
    |> foreign_key_constraint(:report_id)
    |> unique_constraint([:user_phone_hash, :hidden_phone_hash])
  end
end
