defmodule Animina.Repo.Migrations.AddWhatImLookingForCategory do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Shift all existing category positions >= 2 up by 1
    execute("UPDATE trait_categories SET position = position + 1 WHERE position >= 2")
    flush()

    # Insert "What I'm Looking For" category at position 2
    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "What I'm Looking For",
        selection_mode: "multi",
        sensitive: false,
        position: 2,
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"💕", "Long-term Relationship", 1},
      {"💒", "Marriage", 2},
      {"🍸", "Something Casual", 3},
      {"🤝", "Friendship", 4},
      {"🤷", "Don't Know Yet", 5},
      {"☕", "Dates", 6},
      {"🎯", "Shared Activities", 7},
      {"💞", "Open Relationship", 8}
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
    # Remove user flags linked to "What I'm Looking For" flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'What I''m Looking For'
    )
    """)

    # Remove opt-in records for the category
    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'What I''m Looking For'
    )
    """)

    # Remove flags
    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'What I''m Looking For'
    )
    """)

    # Remove category
    execute("DELETE FROM trait_categories WHERE name = 'What I''m Looking For'")

    # Shift all category positions >= 2 back down by 1
    execute("UPDATE trait_categories SET position = position - 1 WHERE position >= 2")
  end
end
