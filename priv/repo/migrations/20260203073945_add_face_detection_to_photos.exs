defmodule Animina.Repo.Migrations.AddFaceDetectionToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :has_face, :boolean
      add :face_score, :float
    end
  end
end
