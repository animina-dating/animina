defmodule Animina.Repo.Migrations.UpdateMoodboardRatingsValidValues do
  use Ecto.Migration

  def change do
    # Remove old constraint that allowed -1, 1, 2
    drop constraint(:moodboard_ratings, :valid_rating_value)

    # Add new constraint: only thumbs up (1) and double thumbs up (2)
    create constraint(:moodboard_ratings, :valid_rating_value, check: "value IN (1, 2)")
  end
end
