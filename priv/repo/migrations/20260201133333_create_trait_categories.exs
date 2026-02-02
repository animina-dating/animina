defmodule Animina.Repo.Migrations.CreateTraitCategories do
  use Ecto.Migration

  def change do
    create table(:trait_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :selection_mode, :string, null: false, default: "multi"
      add :sensitive, :boolean, null: false, default: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trait_categories, [:name])
    create index(:trait_categories, [:position])

    create constraint(:trait_categories, :valid_selection_mode,
             check: "selection_mode IN ('multi', 'single')"
           )
  end
end
