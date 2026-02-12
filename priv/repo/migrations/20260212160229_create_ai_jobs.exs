defmodule Animina.Repo.Migrations.CreateAiJobs do
  use Ecto.Migration

  def change do
    create table(:ai_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_type, :string, null: false
      add :priority, :integer, null: false
      add :status, :string, null: false, default: "pending"
      add :error, :text
      add :attempt, :integer, default: 0
      add :max_attempts, :integer, default: 20
      add :scheduled_at, :utc_datetime
      add :params, :map, null: false
      add :result, :map
      add :model, :string
      add :server_url, :string
      add :prompt, :text
      add :raw_response, :text
      add :duration_ms, :integer
      add :subject_type, :string
      add :subject_id, :binary_id
      add :requester_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:ai_jobs, [:status, :priority, :scheduled_at])
    create index(:ai_jobs, [:job_type])
    create index(:ai_jobs, [:subject_type, :subject_id])
    create index(:ai_jobs, [:inserted_at])
    create index(:ai_jobs, [:status])
    create index(:ai_jobs, [:requester_id])

    drop table(:ollama_logs)
  end
end
