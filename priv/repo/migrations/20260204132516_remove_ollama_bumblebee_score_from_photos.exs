defmodule Animina.Repo.Migrations.RemoveOllamaBumblebeeScoreFromPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      remove :ollama_bumblebee_score, :float
    end
  end
end
