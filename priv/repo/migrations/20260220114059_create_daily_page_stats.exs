defmodule Animina.Repo.Migrations.CreateDailyPageStats do
  use Ecto.Migration

  def change do
    create table(:daily_page_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :path, :string, null: false
      add :view_count, :integer, default: 0
      add :unique_sessions, :integer, default: 0
      add :unique_users, :integer, default: 0
    end

    create unique_index(:daily_page_stats, [:date, :path])
    create index(:daily_page_stats, [:date])
  end
end
