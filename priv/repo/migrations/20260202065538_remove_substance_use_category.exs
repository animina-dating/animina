defmodule Animina.Repo.Migrations.RemoveSubstanceUseCategory do
  use Ecto.Migration

  def up do
    # Remove user flags linked to Substance Use flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Substance Use'
    )
    """)

    # Remove opt-in records for the category
    execute("""
    DELETE FROM user_category_opt_ins
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Substance Use'
    )
    """)

    # Remove flags
    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Substance Use'
    )
    """)

    # Remove category
    execute("DELETE FROM trait_categories WHERE name = 'Substance Use'")
  end

  def down do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    repo().insert_all("trait_categories", [
      %{
        id: Ecto.UUID.dump!(Ecto.UUID.generate()),
        name: "Substance Use",
        selection_mode: "multi",
        sensitive: true,
        position: 6,
        inserted_at: now,
        updated_at: now
      }
    ])

    [{cat_id}] =
      repo().query!("SELECT id FROM trait_categories WHERE name = 'Substance Use'").rows

    flags =
      for {emoji, name, pos} <- [
            {"🚬", "Smoking", 1},
            {"🍻", "Alcohol", 2},
            {"🌿", "Marijuana", 3},
            {"💊", "Hard Drugs", 4},
            {"💉", "Prescription Drug Misuse", 5}
          ] do
        %{
          id: Ecto.UUID.dump!(Ecto.UUID.generate()),
          name: name,
          emoji: emoji,
          category_id: cat_id,
          parent_id: nil,
          position: pos,
          inserted_at: now,
          updated_at: now
        }
      end

    repo().insert_all("trait_flags", flags)
  end
end
