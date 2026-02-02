defmodule Animina.Repo.Migrations.CreateUserCategoryOptIns do
  use Ecto.Migration

  def change do
    create table(:user_category_opt_ins, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :category_id,
          references(:trait_categories, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_category_opt_ins, [:user_id, :category_id])
    create index(:user_category_opt_ins, [:user_id])
  end
end
