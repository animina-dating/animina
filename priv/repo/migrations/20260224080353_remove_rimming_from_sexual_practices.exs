defmodule Animina.Repo.Migrations.RemoveRimmingFromSexualPractices do
  use Ecto.Migration

  def up do
    # Remove user_flags referencing Rimming flags
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT id FROM trait_flags
      WHERE name IN ('Rimming: Giving', 'Rimming: Receiving')
    )
    """)

    # Remove the Rimming flags themselves
    execute("""
    DELETE FROM trait_flags
    WHERE name IN ('Rimming: Giving', 'Rimming: Receiving')
    """)
  end

  def down do
    execute("""
    INSERT INTO trait_flags (id, name, emoji, category_id, parent_id, position, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      flag.name,
      flag.emoji,
      c.id,
      NULL,
      flag.position,
      NOW(),
      NOW()
    FROM (
      VALUES ('💋', 'Rimming: Giving', 7),
             ('💋', 'Rimming: Receiving', 8)
    ) AS flag(emoji, name, position)
    CROSS JOIN trait_categories c
    WHERE c.name = 'Sexual Practices'
    """)
  end
end
