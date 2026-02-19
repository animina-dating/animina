defmodule Animina.Repo.Migrations.RestoreMoodboardRatingsDislike do
  use Ecto.Migration

  def change do
    drop constraint(:moodboard_ratings, :valid_rating_value)
    create constraint(:moodboard_ratings, :valid_rating_value, check: "value IN (-1, 1, 2)")
  end
end
