defmodule Animina.Repo.Migrations.DropUnusedTables do
  use Ecto.Migration

  def change do
    drop table(:daily_discovery_sets)
    drop table(:user_suggestion_views)
  end
end
