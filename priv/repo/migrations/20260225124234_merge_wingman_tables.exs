defmodule Animina.Repo.Migrations.MergeWingmanTables do
  use Ecto.Migration

  def up do
    # Part A: Cancel in-flight preheated_wingman jobs
    execute("""
    UPDATE ai_jobs SET status = 'cancelled', error = 'Merged into wingman_suggestion'
    WHERE job_type = 'preheated_wingman' AND status IN ('pending', 'running')
    """)

    # Part B: Alter wingman_suggestions — make conversation_id nullable, add new fields
    alter table(:wingman_suggestions) do
      modify :conversation_id, :binary_id, null: true

      add :other_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: true
      add :shown_on, :date, null: true
    end

    # Part C: Replace indexes
    drop unique_index(:wingman_suggestions, [:conversation_id, :user_id])

    create unique_index(:wingman_suggestions, [:conversation_id, :user_id],
             where: "conversation_id IS NOT NULL",
             name: :wingman_suggestions_conversation_user_unique
           )

    create unique_index(:wingman_suggestions, [:user_id, :other_user_id, :shown_on],
             where: "conversation_id IS NULL",
             name: :wingman_suggestions_preheated_unique
           )

    create index(:wingman_suggestions, [:user_id, :shown_on])
    create index(:wingman_suggestions, [:shown_on])

    # Part D: Migrate data from preheated_wingman_hints
    # Cast suggestions from jsonb[] to jsonb (both store JSON arrays, different PG column types)
    execute("""
    INSERT INTO wingman_suggestions (id, user_id, other_user_id, shown_on, suggestions, context_hash, ai_job_id, inserted_at, updated_at)
    SELECT id, user_id, other_user_id, shown_on, array_to_json(suggestions)::jsonb, context_hash, ai_job_id, inserted_at, updated_at
    FROM preheated_wingman_hints
    ON CONFLICT DO NOTHING
    """)

    # Part E: Drop the old table
    drop table(:preheated_wingman_hints)
  end

  def down do
    raise "Irreversible migration — cannot restore preheated_wingman_hints table"
  end
end
