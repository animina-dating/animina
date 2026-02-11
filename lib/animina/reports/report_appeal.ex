defmodule Animina.Reports.ReportAppeal do
  @moduledoc """
  Schema for report appeals.

  One appeal per report. Must be reviewed by a different moderator
  than the one who resolved the original report.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User

  @valid_statuses ~w(pending approved rejected)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "report_appeals" do
    belongs_to :report, Animina.Reports.Report
    belongs_to :appellant, User
    belongs_to :reviewer, User

    field :appeal_text, :string
    field :status, :string, default: "pending"
    field :resolution_notes, :string
    field :resolved_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:report_id, :appellant_id, :appeal_text, :status])
    |> validate_required([:report_id, :appellant_id, :appeal_text])
    |> validate_length(:appeal_text, min: 10, max: 2000)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:report_id)
    |> foreign_key_constraint(:appellant_id)
    |> unique_constraint(:report_id)
  end

  def resolve_changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:status, :reviewer_id, :resolution_notes, :resolved_at])
    |> validate_required([:status, :reviewer_id, :resolved_at])
    |> validate_inclusion(:status, ["approved", "rejected"])
    |> foreign_key_constraint(:reviewer_id)
  end

  def valid_statuses, do: @valid_statuses
end
