defmodule Animina.Repo.Migrations.RemoveUnusedPhotoScoreFields do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      remove :nsfw_score, :float
      remove :face_score, :float
    end
  end
end
