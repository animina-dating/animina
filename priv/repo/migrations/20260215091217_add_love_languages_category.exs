defmodule Animina.Repo.Migrations.AddLoveLanguagesCategory do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Insert "Love Languages" category at position 30
    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "Love Languages",
        selection_mode: "single_white",
        sensitive: false,
        position: 30,
        core: false,
        picker_group: "lifestyle",
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"💬", "Words of Affirmation", 1},
      {"⏰", "Quality Time", 2},
      {"🤝", "Acts of Service", 3},
      {"🎁", "Receiving Gifts", 4},
      {"🫂", "Physical Touch", 5}
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
    # Remove user flags linked to "Love Languages" flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Love Languages'
    )
    """)

    # Remove white flag category publish records
    execute("""
    DELETE FROM user_white_flag_category_publishes
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Love Languages'
    )
    """)

    # Remove opt-in records for the category
    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Love Languages'
    )
    """)

    # Remove flags
    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Love Languages'
    )
    """)

    # Remove category
    execute("DELETE FROM trait_categories WHERE name = 'Love Languages'")
  end
end
