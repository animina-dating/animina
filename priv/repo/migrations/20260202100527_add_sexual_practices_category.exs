defmodule Animina.Repo.Migrations.AddSexualPracticesCategory do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Shift all existing category positions >= 20 up by 1
    execute("UPDATE trait_categories SET position = position + 1 WHERE position >= 20")
    flush()

    # Insert "Sexual Practices" category at position 20
    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "Sexual Practices",
        selection_mode: "multi",
        sensitive: true,
        position: 20,
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"👄", "Oral Sex: Giving", 1},
      {"👄", "Oral Sex: Receiving", 2},
      {"🍑", "Anal Sex: Giving", 3},
      {"🍑", "Anal Sex: Receiving", 4},
      {"🤞", "Fingering: Giving", 5},
      {"🤞", "Fingering: Receiving", 6},
      {"💋", "Rimming: Giving", 7},
      {"💋", "Rimming: Receiving", 8},
      {"💆", "Massage: Giving", 9},
      {"💆", "Massage: Receiving", 10},
      {"🔥", "Vaginal Sex", 11},
      {"😘", "Kissing", 12},
      {"🗣️", "Dirty Talk", 13},
      {"📱", "Sexting", 14},
      {"📞", "Phone Sex", 15},
      {"🛏️", "Missionary", 16},
      {"🐕", "Doggy Style", 17},
      {"🤠", "Cowgirl", 18},
      {"🥄", "Spooning", 19},
      {"🔢", "69", 20},
      {"🧍", "Standing", 21},
      {"🧱", "Against the Wall", 22}
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
    # Remove user flags linked to "Sexual Practices" flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Sexual Practices'
    )
    """)

    # Remove opt-in records for the category
    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Sexual Practices'
    )
    """)

    # Remove flags
    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Sexual Practices'
    )
    """)

    # Remove category
    execute("DELETE FROM trait_categories WHERE name = 'Sexual Practices'")

    # Shift all category positions >= 20 back down by 1
    execute("UPDATE trait_categories SET position = position - 1 WHERE position >= 20")
  end
end
