defmodule Animina.Repo.Migrations.CreatePhotoBlacklist do
  use Ecto.Migration

  def change do
    create table(:photo_blacklist, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :dhash, :binary, null: false
      add :reason, :text, null: false
      add :added_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :source_photo_id, references(:photos, type: :binary_id, on_delete: :nilify_all)
      add :source_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:photo_blacklist, [:dhash])
    create index(:photo_blacklist, [:added_by_id])
    create index(:photo_blacklist, [:source_photo_id])
    create index(:photo_blacklist, [:source_user_id])
  end
end
