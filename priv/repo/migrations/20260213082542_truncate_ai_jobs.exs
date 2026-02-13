defmodule Animina.Repo.Migrations.TruncateAiJobs do
  use Ecto.Migration

  def up do
    execute("TRUNCATE ai_jobs")
  end

  def down do
    # Data cannot be restored
  end
end
