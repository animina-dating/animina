defmodule Animina.Repo.Migrations.AddUserWhiteFlagCategoryPublish do
  use Ecto.Migration

  def change do
    create table(:user_white_flag_category_publish, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :category_id,
          references(:trait_categories, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_white_flag_category_publish, [:user_id, :category_id])
    create index(:user_white_flag_category_publish, [:user_id])
  end
end
