defmodule Animina.Repo.Migrations.CreateMoodboardItems do
  use Ecto.Migration

  def change do
    # Core container for gallery content
    create table(:moodboard_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :item_type, :string, null: false
      add :position, :integer, null: false, default: 0
      add :state, :string, null: false, default: "active"
      add :pinned, :boolean, default: false, null: false
      add :hidden_at, :utc_datetime
      add :hidden_reason, :string

      timestamps(type: :utc_datetime)
    end

    create index(:moodboard_items, [:user_id])
    create index(:moodboard_items, [:user_id, :state])
    create index(:moodboard_items, [:user_id, :position])

    create constraint(:moodboard_items, :valid_item_type,
      check: "item_type IN ('photo', 'story', 'combined')"
    )

    create constraint(:moodboard_items, :valid_state,
      check: "state IN ('active', 'hidden', 'deleted')"
    )

    # Pinned items MUST be at position 1
    create constraint(:moodboard_items, :pinned_must_be_position_one,
      check: "(NOT pinned) OR (pinned AND position = 1)"
    )

    # Only one pinned item per user (excluding deleted items)
    create unique_index(:moodboard_items, [:user_id],
      where: "pinned = true AND state != 'deleted'",
      name: :moodboard_items_user_pinned_unique
    )

    # Markdown story content
    create table(:moodboard_stories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :moodboard_item_id, references(:moodboard_items, type: :binary_id, on_delete: :delete_all),
        null: false

      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:moodboard_stories, [:moodboard_item_id])

    # Links gallery items to photos
    create table(:moodboard_photos, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :moodboard_item_id, references(:moodboard_items, type: :binary_id, on_delete: :delete_all),
        null: false

      add :photo_id, references(:photos, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:moodboard_photos, [:moodboard_item_id])
    create index(:moodboard_photos, [:photo_id])
  end
end
