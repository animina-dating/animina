defmodule Animina.Repo.Migrations.AddDeletedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :deleted_at, :utc_datetime
    end

    create index(:users, [:deleted_at], where: "deleted_at IS NOT NULL")
  end
end
