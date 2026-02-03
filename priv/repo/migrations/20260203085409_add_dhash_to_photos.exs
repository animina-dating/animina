defmodule Animina.Repo.Migrations.AddDhashToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :dhash, :binary
    end

    create index(:photos, [:dhash])
  end
end
