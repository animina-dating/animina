defmodule Animina.Repo.Migrations.AddTravelStyleFlags do
  use Ecto.Migration

  import Ecto.Query

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Get the Travels category ID
    cat_id =
      repo().one(
        from(c in "trait_categories", where: c.name == "Travels", select: c.id)
      )

    flags =
      [
        %{name: "Luxury", emoji: "💎", position: 11},
        %{name: "Backpacking", emoji: "🎒", position: 12},
        %{name: "Low-Budget", emoji: "💰", position: 13},
        %{name: "Adventure Travel", emoji: "🌍", position: 14}
      ]

    rows =
      Enum.map(flags, fn flag ->
        {:ok, id_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        %{
          id: id_bin,
          name: flag.name,
          emoji: flag.emoji,
          category_id: cat_id,
          parent_id: nil,
          position: flag.position,
          inserted_at: now,
          updated_at: now
        }
      end)

    repo().insert_all("trait_flags", rows)
  end

  def down do
    import Ecto.Query

    cat_id =
      repo().one(
        from(c in "trait_categories", where: c.name == "Travels", select: c.id)
      )

    flag_ids =
      repo().all(
        from(f in "trait_flags",
          where:
            f.category_id == ^cat_id and
              f.name in ["Luxury", "Backpacking", "Low-Budget", "Adventure Travel"],
          select: f.id
        )
      )

    # Remove user flags referencing these flags
    repo().delete_all(from(uf in "user_flags", where: uf.flag_id in ^flag_ids))

    # Remove the flags
    repo().delete_all(
      from(f in "trait_flags",
        where:
          f.category_id == ^cat_id and
            f.name in ["Luxury", "Backpacking", "Low-Budget", "Adventure Travel"]
      )
    )
  end
end
