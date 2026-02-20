defmodule Animina.Repo.Migrations.CreateWingmanSuggestions do
  use Ecto.Migration

  def change do
    create table(:wingman_suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :suggestions, :map
      add :context_hash, :string
      add :ai_job_id, references(:ai_jobs, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wingman_suggestions, [:conversation_id, :user_id])
    create index(:wingman_suggestions, [:user_id])
  end
end
