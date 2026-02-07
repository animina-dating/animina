defmodule Animina.Repo.Migrations.ChangeOllamaLogsPhotoIdToDeleteAll do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE ollama_logs DROP CONSTRAINT IF EXISTS ollama_logs_photo_id_fkey"

    alter table(:ollama_logs) do
      modify :photo_id, references(:photos, type: :binary_id, on_delete: :delete_all)
    end
  end

  def down do
    execute "ALTER TABLE ollama_logs DROP CONSTRAINT IF EXISTS ollama_logs_photo_id_fkey"

    alter table(:ollama_logs) do
      modify :photo_id, references(:photos, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
