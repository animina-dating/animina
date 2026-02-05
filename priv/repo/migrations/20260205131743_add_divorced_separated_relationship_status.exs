defmodule Animina.Repo.Migrations.AddDivorcedSeparatedRelationshipStatus do
  use Ecto.Migration

  import Ecto.Query

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Get the Relationship Status category ID
    cat_id =
      repo().one(
        from(c in "trait_categories", where: c.name == "Relationship Status", select: c.id)
      )

    # Update "It's Complicated" to position 6
    repo().update_all(
      from(f in "trait_flags",
        where: f.category_id == ^cat_id and f.name == "It's Complicated"
      ),
      set: [position: 6, updated_at: now]
    )

    # Insert Separated at position 4
    {:ok, sep_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_flags", [
      %{
        id: sep_bin,
        name: "Separated",
        emoji: "💔",
        category_id: cat_id,
        parent_id: nil,
        position: 4,
        inserted_at: now,
        updated_at: now
      }
    ])

    # Insert Divorced at position 5
    {:ok, div_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_flags", [
      %{
        id: div_bin,
        name: "Divorced",
        emoji: "📝",
        category_id: cat_id,
        parent_id: nil,
        position: 5,
        inserted_at: now,
        updated_at: now
      }
    ])
  end

  def down do
    import Ecto.Query

    # Get the Relationship Status category ID
    cat_id =
      repo().one(
        from(c in "trait_categories", where: c.name == "Relationship Status", select: c.id)
      )

    # Get IDs of flags to delete
    flag_ids =
      repo().all(
        from(f in "trait_flags",
          where: f.category_id == ^cat_id and f.name in ["Separated", "Divorced"],
          select: f.id
        )
      )

    # Remove user flags referencing these flags
    repo().delete_all(from(uf in "user_flags", where: uf.flag_id in ^flag_ids))

    # Remove the flags
    repo().delete_all(
      from(f in "trait_flags",
        where: f.category_id == ^cat_id and f.name in ["Separated", "Divorced"]
      )
    )

    # Reset "It's Complicated" back to position 4
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    repo().update_all(
      from(f in "trait_flags",
        where: f.category_id == ^cat_id and f.name == "It's Complicated"
      ),
      set: [position: 4, updated_at: now]
    )
  end
end
