defmodule Animina.Repo.Migrations.CreateCountries do
  use Ecto.Migration

  def change do
    create table(:countries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :code, :string, size: 2, null: false

      timestamps()
    end

    create unique_index(:countries, [:code])
  end
end
