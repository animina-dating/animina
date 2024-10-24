defmodule Animina.Repo.Migrations.MigrateResources16 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      modify :state, :text, null: true, default: nil
    end

    alter table(:photos) do
      remove :tagged
    end
  end

  def down do
    alter table(:photos) do
      add :tagged, :boolean, default: false
    end

    alter table(:users) do
      modify :state, :text, null: false, default: "normal"
    end
  end
end
