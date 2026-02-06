defmodule Animina.Repo.Migrations.CreateUserPopularityStats do
  use Ecto.Migration

  def change do
    create table(:user_popularity_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :stat_date, :date, null: false
      add :daily_inquiry_count, :integer, null: false, default: 0
      add :avg_7_day, :float
      add :avg_30_day, :float

      timestamps(type: :utc_datetime)
    end

    # One stat per user per day
    create unique_index(:user_popularity_stats, [:user_id, :stat_date])

    # For cleanup of old stats
    create index(:user_popularity_stats, [:stat_date])
  end
end
