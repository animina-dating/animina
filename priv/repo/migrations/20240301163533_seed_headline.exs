defmodule Animina.Repo.Migrations.SeedHeadline do
  @moduledoc """
  Seeds headlines.
  """

  use Ecto.Migration

  def up do
    seed_headlines()
  end

  def down do
  end

  defp seed_headlines() do
    headlines()
    |> Animina.Narratives.bulk_create(Animina.Narratives.Headline, :create,
      return_stream?: false,
      return_records?: false,
      batch_size: 100
    )
  end

  defp headlines do
    [
      %{subject: "The story behind my smile in this photo", position: 1},
      %{subject: "Caught in the moment doing what I love", position: 2},
      %{subject: "A place I'd go back to in a heartbeat", position: 3},
      %{subject: "My idea of a perfect day", position: 4},
      %{subject: "Just me enjoying my favorite hobby", position: 5},
      %{subject: "The adventure that left me speechless", position: 6},
      %{subject: "A talent I'm proud of", position: 7},
      %{subject: "A tradition I hold dear", position: 8},
      %{subject: "A meal I can cook to perfection", position: 9},
      %{subject: "My favorite meal", position: 10},
      %{subject: "A book that changed my perspective", position: 11},
      %{subject: "The joy of finding something new", position: 12},
      %{subject: "A moment of pure bliss", position: 13},
      %{subject: "An achievement I'm really proud of", position: 14},
      %{subject: "A lesson learned the hard way", position: 15},
      %{subject: "Something I've created", position: 16},
      %{subject: "A glimpse into my daily life", position: 17},
      %{subject: "A place where I feel most at peace", position: 18},
      %{subject: "A friendship that means the world to me", position: 19},
      %{subject: "A challenge I've overcome", position: 20},
      %{subject: "My favorite way to relax", position: 21},
      %{subject: "An unforgettable night out", position: 22},
      %{subject: "A family tradition I love", position: 23},
      %{subject: "An impulse decision that was totally worth it", position: 24},
      %{subject: "A moment that took my breath away", position: 25},
      %{subject: "Just a casual day out", position: 26},
      %{subject: "My favorite childhood memory", position: 27},
      %{subject: "A pet I adore", position: 28},
      %{subject: "Something that always makes me laugh", position: 29},
      %{subject: "A hobby I've recently picked up", position: 30},
      %{subject: "A dream I'm chasing", position: 31},
      %{subject: "Out of my comfort zone", position: 32},
      %{subject: "Monday", position: 33},
      %{subject: "Tuesday", position: 34},
      %{subject: "Wednesday", position: 35},
      %{subject: "Thursday", position: 36},
      %{subject: "Friday", position: 37},
      %{subject: "Saturday", position: 38},
      %{subject: "Sunday", position: 39},
      %{subject: "Spring", position: 40},
      %{subject: "Summer", position: 41},
      %{subject: "Fall", position: 42},
      %{subject: "Winter", position: 43},
      %{subject: "About me", position: 44}
    ]
  end
end
