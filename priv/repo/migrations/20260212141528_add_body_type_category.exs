defmodule Animina.Repo.Migrations.AddBodyTypeCategory do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Shift all existing category positions >= 7 up by 1
    execute("UPDATE trait_categories SET position = position + 1 WHERE position >= 7")
    flush()

    # Insert "Body Type" category at position 7
    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "Body Type",
        selection_mode: "single",
        sensitive: true,
        position: 7,
        core: false,
        picker_group: "sensitive",
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"🦊", "Slim", 1},
      {"📏", "Average", 2},
      {"🏋️", "Athletic", 3},
      {"🧸", "Curvy", 4},
      {"🐻", "Plus-Size", 5}
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
    # Remove user flags linked to "Body Type" flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Body Type'
    )
    """)

    # Remove opt-in records for the category
    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Body Type'
    )
    """)

    # Remove flags
    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Body Type'
    )
    """)

    # Remove category
    execute("DELETE FROM trait_categories WHERE name = 'Body Type'")

    # Shift all category positions >= 7 back down by 1
    execute("UPDATE trait_categories SET position = position - 1 WHERE position >= 7")
  end
end
