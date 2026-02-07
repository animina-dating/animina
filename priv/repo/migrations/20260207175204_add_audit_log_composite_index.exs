defmodule Animina.Repo.Migrations.AddAuditLogCompositeIndex do
  use Ecto.Migration

  def change do
    create index(:photo_audit_logs, [:photo_id, :inserted_at, :event_type],
             name: :photo_audit_logs_photo_time_event_idx
           )
  end
end
