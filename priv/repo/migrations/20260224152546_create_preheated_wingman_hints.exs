defmodule Animina.Repo.Migrations.CreatePreheatedWingmanHints do
  use Ecto.Migration

  def change do
    create table(:preheated_wingman_hints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :other_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :shown_on, :date, null: false
      add :suggestions, {:array, :map}
      add :context_hash, :string
      add :ai_job_id, references(:ai_jobs, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:preheated_wingman_hints, [:user_id, :other_user_id, :shown_on])
    create index(:preheated_wingman_hints, [:user_id, :shown_on])
    create index(:preheated_wingman_hints, [:shown_on])
  end
end
