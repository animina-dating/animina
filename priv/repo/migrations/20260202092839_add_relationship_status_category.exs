defmodule Animina.Repo.Migrations.AddRelationshipStatusCategory do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Shift all existing category positions up by 1
    execute("UPDATE trait_categories SET position = position + 1")
    flush()

    # Insert Relationship Status category at position 1
    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "Relationship Status",
        selection_mode: "single_white",
        sensitive: false,
        position: 1,
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"🙋", "Single", 1},
      {"💑", "In a Relationship", 2},
      {"💍", "Married", 3},
      {"🤷", "It's Complicated", 4}
    ]

    flag_rows =
      Enum.map(flags, fn {emoji, name, position} ->
        {:ok, bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        %{
          id: bin,
          name: name,
          emoji: emoji,
          category_id: cat_bin,
          parent_id: nil,
          position: position,
          inserted_at: now,
          updated_at: now
        }
      end)

    repo().insert_all("trait_flags", flag_rows)
  end

  def down do
    # Remove user flags linked to Relationship Status flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Relationship Status'
    )
    """)

    # Remove opt-in records for the category
    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Relationship Status'
    )
    """)

    # Remove flags
    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Relationship Status'
    )
    """)

    # Remove category
    execute("DELETE FROM trait_categories WHERE name = 'Relationship Status'")

    # Shift all category positions back down by 1
    execute("UPDATE trait_categories SET position = position - 1")
  end
end
