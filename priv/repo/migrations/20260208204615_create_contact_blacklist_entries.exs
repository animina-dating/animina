defmodule Animina.Repo.Migrations.CreateContactBlacklistEntries do
  use Ecto.Migration

  def change do
    create table(:contact_blacklist_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :entry_type, :string, null: false
      add :value, :string, null: false
      add :label, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_blacklist_entries, [:user_id, :value])
    create index(:contact_blacklist_entries, [:value])
    create index(:contact_blacklist_entries, [:user_id])
  end
end
