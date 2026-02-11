defmodule Animina.Repo.Migrations.CreateUserReports do
  use Ecto.Migration

  def change do
    create table(:user_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reporter_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reported_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reporter_phone_hash, :string, null: false
      add :reported_phone_hash, :string, null: false
      add :category, :string, null: false
      add :description, :text
      add :context_type, :string, null: false
      add :context_reference_id, :binary_id
      add :status, :string, null: false, default: "pending"
      add :resolution, :string
      add :resolution_notes, :text
      add :priority, :string, null: false
      add :resolver_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:user_reports, [:reporter_id])
    create index(:user_reports, [:reported_user_id])
    create index(:user_reports, [:reported_phone_hash])
    create index(:user_reports, [:reporter_phone_hash])
    create index(:user_reports, [:status])
    create index(:user_reports, [:priority, :status, :inserted_at])
  end
end
