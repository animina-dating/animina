defmodule Animina.Repo.Migrations.CreateReportEvidence do
  use Ecto.Migration

  def change do
    create table(:report_evidence, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :report_id, references(:user_reports, type: :binary_id, on_delete: :delete_all),
        null: false

      add :conversation_snapshot, :map
      add :moodboard_snapshot, :map
      add :profile_snapshot, :map
      add :snapshot_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:report_evidence, [:report_id])
  end
end
