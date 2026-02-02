defmodule Animina.Repo.Migrations.AddLanguagesCategory do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Insert "Languages" category at position 26 (after Sexual Practices at 25)
    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "Languages",
        selection_mode: "multi",
        sensitive: false,
        exclusive_hard: false,
        core: true,
        picker_group: nil,
        position: 26,
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"🇩🇪", "Deutsch", 1},
      {"🇬🇧", "English", 2},
      {"🇹🇷", "Türkçe", 3},
      {"🇷🇺", "Русский", 4},
      {"🇸🇦", "العربية", 5},
      {"🇵🇱", "Polski", 6},
      {"🇫🇷", "Français", 7},
      {"🇪🇸", "Español", 8},
      {"🇺🇦", "Українська", 9}
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
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Languages'
    )
    """)

    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Languages'
    )
    """)

    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Languages'
    )
    """)

    execute("DELETE FROM trait_categories WHERE name = 'Languages'")
  end
end
