defmodule Animina.Repo.Migrations.RemoveOmnivoreFlag do
  use Ecto.Migration

  def up do
    # Remove user flags referencing the Omnivore flag
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT id FROM trait_flags WHERE name = 'Omnivore'
      AND category_id IN (SELECT id FROM trait_categories WHERE name = 'Diet')
    )
    """)

    # Remove the Omnivore flag itself
    execute("""
    DELETE FROM trait_flags
    WHERE name = 'Omnivore'
    AND category_id IN (SELECT id FROM trait_categories WHERE name = 'Diet')
    """)

    # Shift remaining Diet flag positions down by 1
    execute("""
    UPDATE trait_flags
    SET position = position - 1
    WHERE category_id IN (SELECT id FROM trait_categories WHERE name = 'Diet')
    AND position > 1
    """)
  end

  def down do
    # Shift existing Diet flag positions up by 1 to make room at position 1
    execute("""
    UPDATE trait_flags
    SET position = position + 1
    WHERE category_id IN (SELECT id FROM trait_categories WHERE name = 'Diet')
    """)

    # Re-insert the Omnivore flag at position 1
    execute("""
    INSERT INTO trait_flags (id, name, emoji, category_id, parent_id, position, inserted_at, updated_at)
    SELECT gen_random_uuid(), 'Omnivore', '🍖', id, NULL, 1, NOW(), NOW()
    FROM trait_categories WHERE name = 'Diet'
    """)
  end
end
