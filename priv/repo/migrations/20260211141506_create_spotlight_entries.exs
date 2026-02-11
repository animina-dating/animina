defmodule Animina.Repo.Migrations.CreateSpotlightEntries do
  use Ecto.Migration

  def change do
    create table(:spotlight_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :shown_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :shown_on, :date, null: false
      add :is_wildcard, :boolean, default: false, null: false
      add :cycle_number, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    # No duplicate per day
    create unique_index(:spotlight_entries, [:user_id, :shown_user_id, :shown_on])

    # Today's set lookup
    create index(:spotlight_entries, [:user_id, :shown_on])

    # Bidirectional access check
    create index(:spotlight_entries, [:shown_user_id, :shown_on])
  end
end
