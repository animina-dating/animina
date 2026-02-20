defmodule Animina.Repo.Migrations.CreateAdVisits do
  use Ecto.Migration

  def change do
    create table(:ad_visits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ad_id, references(:ads, type: :binary_id, on_delete: :delete_all), null: false
      add :ip_address, :string
      add :user_agent, :string, size: 500
      add :referer, :string, size: 500
      add :os, :string
      add :browser, :string
      add :device_type, :string
      add :device_model, :string
      add :language, :string
      add :is_bot, :boolean, default: false
      add :visited_at, :utc_datetime, null: false
    end

    create index(:ad_visits, [:ad_id])
    create index(:ad_visits, [:visited_at])
    create index(:ad_visits, [:ad_id, :visited_at])
  end
end
