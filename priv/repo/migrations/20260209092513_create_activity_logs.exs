defmodule Animina.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :subject_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :category, :string, null: false
      add :event, :string, null: false
      add :metadata, :map, default: %{}, null: false
      add :summary, :string, null: false

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:activity_logs, [:inserted_at])
    create index(:activity_logs, [:actor_id, :inserted_at])
    create index(:activity_logs, [:subject_id, :inserted_at])
    create index(:activity_logs, [:category, :inserted_at])
    create index(:activity_logs, [:category, :event, :inserted_at])
  end
end
