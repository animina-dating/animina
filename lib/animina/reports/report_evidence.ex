defmodule Animina.Reports.ReportEvidence do
  @moduledoc """
  Schema for report evidence snapshots.

  Captures conversation messages, moodboard items, and profile data
  at the time of the report for moderator review.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "report_evidence" do
    belongs_to :report, Animina.Reports.Report

    field :conversation_snapshot, :map
    field :moodboard_snapshot, :map
    field :profile_snapshot, :map
    field :snapshot_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [
      :report_id,
      :conversation_snapshot,
      :moodboard_snapshot,
      :profile_snapshot,
      :snapshot_at
    ])
    |> validate_required([:report_id, :snapshot_at])
    |> foreign_key_constraint(:report_id)
    |> unique_constraint(:report_id)
  end
end
