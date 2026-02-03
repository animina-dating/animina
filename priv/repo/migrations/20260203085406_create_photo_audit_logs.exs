defmodule Animina.Repo.Migrations.CreatePhotoAuditLogs do
  use Ecto.Migration

  def change do
    create table(:photo_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :photo_id, references(:photos, type: :binary_id, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :actor_type, :string, null: false
      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :details, :map, default: %{}

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:photo_audit_logs, [:photo_id])
    create index(:photo_audit_logs, [:actor_id])
    create index(:photo_audit_logs, [:event_type])
    create index(:photo_audit_logs, [:inserted_at])
  end
end
