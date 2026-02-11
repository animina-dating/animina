defmodule Animina.Repo.Migrations.CreateStrikeRecords do
  use Ecto.Migration

  def change do
    create table(:strike_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone_hash, :string, null: false
      add :email_hash, :string, null: false

      add :report_id, references(:user_reports, type: :binary_id, on_delete: :restrict),
        null: false

      add :resolution, :string, null: false
      add :category, :string, null: false
      add :resolved_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:strike_records, [:phone_hash])
    create index(:strike_records, [:email_hash])
  end
end
