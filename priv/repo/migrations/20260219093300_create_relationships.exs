defmodule Animina.Repo.Migrations.CreateRelationships do
  use Ecto.Migration

  def change do
    create table(:relationships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_a_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :user_b_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :status, :string, null: false, default: "chatting"
      add :status_changed_at, :utc_datetime
      add :status_changed_by, :binary_id

      add :pending_status, :string
      add :pending_proposed_by, :binary_id
      add :pending_proposed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:relationships, [:user_a_id, :user_b_id])
    create index(:relationships, [:user_a_id])
    create index(:relationships, [:user_b_id])
    create index(:relationships, [:status])

    create table(:relationship_overrides, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :relationship_id, references(:relationships, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :can_see_profile, :boolean
      add :can_message_me, :boolean
      add :visible_in_discovery, :boolean

      timestamps(type: :utc_datetime)
    end

    create unique_index(:relationship_overrides, [:relationship_id, :user_id])
    create index(:relationship_overrides, [:user_id])

    create table(:relationship_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :relationship_id, references(:relationships, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :from_status, :string
      add :to_status, :string, null: false
      add :event_type, :string, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:relationship_events, [:relationship_id])
    create index(:relationship_events, [:actor_id, :event_type])
    create index(:relationship_events, [:to_status])
  end
end
