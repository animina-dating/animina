defmodule Animina.Repo.Migrations.CreateDailyFunnelStats do
  use Ecto.Migration

  def change do
    create table(:daily_funnel_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :visitors, :integer, default: 0
      add :registered, :integer, default: 0
      add :profile_completed, :integer, default: 0
      add :first_message, :integer, default: 0
      add :mutual_match, :integer, default: 0
    end

    create unique_index(:daily_funnel_stats, [:date])
  end
end
