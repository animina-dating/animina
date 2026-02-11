defmodule Animina.Repo.Migrations.CreateReportInvisibilities do
  use Ecto.Migration

  def change do
    create table(:report_invisibilities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :hidden_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :user_phone_hash, :string, null: false
      add :hidden_phone_hash, :string, null: false

      add :report_id, references(:user_reports, type: :binary_id, on_delete: :restrict),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:report_invisibilities, [:user_phone_hash, :hidden_phone_hash])
    create index(:report_invisibilities, [:user_id])
    create index(:report_invisibilities, [:hidden_user_id])
    create index(:report_invisibilities, [:user_phone_hash])
    create index(:report_invisibilities, [:hidden_phone_hash])
  end
end
