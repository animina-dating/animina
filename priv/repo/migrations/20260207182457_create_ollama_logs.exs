defmodule Animina.Repo.Migrations.CreateOllamaLogs do
  use Ecto.Migration

  def change do
    create table(:ollama_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :photo_id, references(:photos, type: :binary_id, on_delete: :nilify_all)
      add :owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :requester_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :prompt, :text
      add :result, :text
      add :duration_ms, :integer
      add :model, :string
      add :server_url, :string
      add :status, :string
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:ollama_logs, [:inserted_at])
    create index(:ollama_logs, [:photo_id])
    create index(:ollama_logs, [:model])
    create index(:ollama_logs, [:status])
    create index(:ollama_logs, [:owner_id])
  end
end
