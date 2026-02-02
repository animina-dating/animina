defmodule Animina.Repo.Migrations.AddVersions do
  use Ecto.Migration

  def change do
    create table(:versions, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :event, :string, null: false, size: 10
      add :item_type, :string, null: false
      add :item_id, :uuid
      add :item_changes, :map, null: false
      add :originator_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :origin, :string, size: 50
      add :meta, :map

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:versions, [:originator_id])
    create index(:versions, [:item_id, :item_type])
    create index(:versions, [:inserted_at])
  end
end
