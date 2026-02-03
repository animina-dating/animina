defmodule Animina.Repo.Migrations.AllowNullReasonInPhotoBlacklist do
  use Ecto.Migration

  def change do
    alter table(:photo_blacklist) do
      modify :reason, :string, null: true
    end
  end
end
