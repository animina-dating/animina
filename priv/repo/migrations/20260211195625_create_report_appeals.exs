defmodule Animina.Repo.Migrations.CreateReportAppeals do
  use Ecto.Migration

  def change do
    create table(:report_appeals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :report_id, references(:user_reports, type: :binary_id, on_delete: :delete_all),
        null: false

      add :appellant_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :appeal_text, :text, null: false
      add :status, :string, null: false, default: "pending"
      add :reviewer_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :resolution_notes, :text
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:report_appeals, [:report_id])
    create index(:report_appeals, [:status])
  end
end
