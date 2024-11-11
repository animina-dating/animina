defmodule Animina.Repo.Migrations.RemoveOldStoryPhotos do
  @moduledoc """
  Deletes invalid story photos from the database and the filesystem.
  """

  use Ecto.Migration

  alias Animina.Accounts.Photo
  import Ecto.Query
  require Logger

  def up do
    {:ok,  photos_query} = Ash.Query.new(Photo) |> Ash.Query.data_layer_query()

    # query groups photos by story_id and selects the most recent photo for a story by the latest created_at
    latest_photos_query =
      from p in photos_query,
        group_by: [p.story_id],
        select: %{
          story_id: p.story_id,
          latest_created_at: max(p.created_at),
        }

    # query selects the photos that are valid
    valid_photos_query =
      from p in photos_query,
        join: l in subquery(latest_photos_query),
        on: p.story_id == l.story_id and p.created_at == l.latest_created_at,
        select: %{story_id: p.story_id, photo_id: p.id}

    # get the valid photos
    valid_photos = repo().all(valid_photos_query)

    # get the ids of the valid photos
    valid_photos_ids = Enum.map(valid_photos, fn x -> x.photo_id end)

    # query selects the photos that are invalid
    delete_invalid_photos_query =
      from p in photos_query,
        where: p.id not in ^valid_photos_ids

    # get the invalid photos
    invalid_photos = repo().all(delete_invalid_photos_query)

    # delete the invalid photos
    {count, _} = repo().delete_all(delete_invalid_photos_query)

    # remove the invalid photos from the filesystem
    Enum.each(invalid_photos, fn photo -> Photo.delete_photo_and_optimized_photos(photo) end)

    Logger.info("Deleted #{count} invalid photos")
  end

  def down do
  end
end
