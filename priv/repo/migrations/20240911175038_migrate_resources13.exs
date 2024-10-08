defmodule Animina.Repo.Migrations.MigrateResources13 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:photos) do
      add :description, :text
    end
  end

  def down do
    alter table(:photos) do
      remove :description
    end
  end
end
