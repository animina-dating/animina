defmodule Animina.Repo.Migrations.CreateCities do
  use Ecto.Migration

  def change do
    create table(:cities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :citext, null: false
      add :zip_code, :string, null: false
      add :county, :citext, null: false
      add :federal_state, :citext, null: false
      add :lat, :float, null: false
      add :lon, :float, null: false

      add :country_id, references(:countries, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:cities, [:zip_code])
    create index(:cities, [:country_id])
    create index(:cities, [:name])
  end
end
