defmodule Animina.Repo.Migrations.CreateMoodboardRatings do
  use Ecto.Migration

  def change do
    create table(:moodboard_ratings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :moodboard_item_id,
          references(:moodboard_items, type: :binary_id, on_delete: :delete_all),
          null: false

      add :value, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:moodboard_ratings, [:user_id, :moodboard_item_id])
    create index(:moodboard_ratings, [:moodboard_item_id, :value])

    create constraint(:moodboard_ratings, :valid_rating_value, check: "value IN (-1, 1, 2)")
  end
end
