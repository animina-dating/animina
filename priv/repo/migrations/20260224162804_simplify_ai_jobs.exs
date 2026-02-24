defmodule Animina.Repo.Migrations.SimplifyAiJobs do
  use Ecto.Migration

  def up do
    # Delete all existing AI jobs — clean slate for the new queue system
    execute "TRUNCATE ai_jobs CASCADE"

    # Clear photo descriptions (feature removed)
    execute "UPDATE photos SET description = NULL, description_generated_at = NULL WHERE description IS NOT NULL"
  end

  def down do
    # Data-only migration — no schema changes to revert
    :ok
  end
end
