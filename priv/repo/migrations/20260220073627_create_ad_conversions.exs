defmodule Animina.Repo.Migrations.CreateAdConversions do
  use Ecto.Migration

  def change do
    create table(:ad_conversions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ad_id, references(:ads, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :converted_at, :utc_datetime, null: false
    end

    create index(:ad_conversions, [:ad_id])
    create index(:ad_conversions, [:user_id])
    create index(:ad_conversions, [:ad_id, :converted_at])
    create unique_index(:ad_conversions, [:ad_id, :user_id])
  end
end
