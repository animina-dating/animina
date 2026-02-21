defmodule Animina.Repo.Migrations.AddExpiresAtToAiJobs do
  use Ecto.Migration

  def change do
    alter table(:ai_jobs) do
      add :expires_at, :utc_datetime
    end

    create index(:ai_jobs, [:expires_at], where: "expires_at IS NOT NULL")
  end
end
