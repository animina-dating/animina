defmodule Animina.Repo.Migrations.AddThumbnailToPhotoBlacklist do
  use Ecto.Migration

  def change do
    alter table(:photo_blacklist) do
      add :thumbnail_path, :string
    end
  end
end
