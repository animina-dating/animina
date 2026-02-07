defmodule Animina.Repo.Migrations.CreateDailyDiscoverySets do
  use Ecto.Migration

  def change do
    create table(:daily_discovery_sets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :candidate_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :set_date, :date, null: false
      add :is_wildcard, :boolean, default: false, null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:daily_discovery_sets, [:user_id, :set_date, :candidate_id])
    create index(:daily_discovery_sets, [:user_id, :set_date])
  end
end
