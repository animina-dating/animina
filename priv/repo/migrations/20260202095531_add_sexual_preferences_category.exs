defmodule Animina.Repo.Migrations.AddSexualPreferencesCategory do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Shift all existing category positions >= 19 up by 1
    execute("UPDATE trait_categories SET position = position + 1 WHERE position >= 19")
    flush()

    # Insert "Sexual Preferences" category at position 19
    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "Sexual Preferences",
        selection_mode: "multi",
        sensitive: true,
        position: 19,
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"🍦", "Vanilla", 1},
      {"👑", "Dominant", 2},
      {"🧎", "Submissive", 3},
      {"🔄", "Switch", 4},
      {"⛓️", "Bondage", 5},
      {"🖤", "S&M", 6},
      {"🎭", "Role Play", 7},
      {"🕉️", "Tantra", 8},
      {"👠", "Fetish", 9},
      {"🔦", "Exhibitionism", 10},
      {"👀", "Voyeurism", 11},
      {"👥", "Group Play", 12},
      {"🎲", "Toys", 13},
      {"🔁", "Swinging", 14}
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
    # Remove user flags linked to "Sexual Preferences" flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Sexual Preferences'
    )
    """)

    # Remove opt-in records for the category
    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Sexual Preferences'
    )
    """)

    # Remove flags
    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Sexual Preferences'
    )
    """)

    # Remove category
    execute("DELETE FROM trait_categories WHERE name = 'Sexual Preferences'")

    # Shift all category positions >= 19 back down by 1
    execute("UPDATE trait_categories SET position = position - 1 WHERE position >= 19")
  end
end
