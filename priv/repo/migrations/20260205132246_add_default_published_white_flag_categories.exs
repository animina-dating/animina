defmodule Animina.Repo.Migrations.AddDefaultPublishedWhiteFlagCategories do
  use Ecto.Migration

  import Ecto.Query

  @default_published_categories ["Relationship Status", "What I'm Looking For", "Languages"]

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Get the category IDs for the default published categories
    category_ids =
      repo().all(
        from(c in "trait_categories",
          where: c.name in ^@default_published_categories,
          select: c.id
        )
      )

    # Get all user IDs
    user_ids = repo().all(from(u in "users", select: u.id))

    # For each user and category combination, create a publish record if it doesn't exist
    for user_id <- user_ids, category_id <- category_ids do
      # Check if record already exists
      exists =
        repo().exists?(
          from(p in "user_white_flag_category_publish",
            where: p.user_id == ^user_id and p.category_id == ^category_id
          )
        )

      unless exists do
        {:ok, id_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        repo().insert_all(
          "user_white_flag_category_publish",
          [
            %{
              id: id_bin,
              user_id: user_id,
              category_id: category_id,
              inserted_at: now,
              updated_at: now
            }
          ],
          on_conflict: :nothing
        )
      end
    end
  end

  def down do
    # Get the category IDs for the default published categories
    category_ids =
      repo().all(
        from(c in "trait_categories",
          where: c.name in ^@default_published_categories,
          select: c.id
        )
      )

    # Remove all publish records for these categories
    repo().delete_all(
      from(p in "user_white_flag_category_publish",
        where: p.category_id in ^category_ids
      )
    )
  end
end
