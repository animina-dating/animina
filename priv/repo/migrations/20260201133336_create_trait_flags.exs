defmodule Animina.Repo.Migrations.CreateTraitFlags do
  use Ecto.Migration

  def change do
    create table(:trait_flags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :emoji, :string
      add :position, :integer, null: false

      add :category_id, references(:trait_categories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_id, references(:trait_flags, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trait_flags, [:category_id, :name])
    create index(:trait_flags, [:category_id])
    create index(:trait_flags, [:parent_id])
    create index(:trait_flags, [:position])
  end
end
