defmodule Animina.Repo.Migrations.AddTimingToPhotoAuditLogs do
  use Ecto.Migration

  def change do
    alter table(:photo_audit_logs) do
      # Duration of the operation in milliseconds (for performance analysis)
      add :duration_ms, :integer

      # Ollama server URL used for this request (for tracking server usage)
      add :ollama_server_url, :string
    end

    # Index for analyzing performance by duration
    create index(:photo_audit_logs, [:duration_ms])
  end
end
