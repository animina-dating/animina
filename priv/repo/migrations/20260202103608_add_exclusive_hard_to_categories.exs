defmodule Animina.Repo.Migrations.AddExclusiveHardToCategories do
  use Ecto.Migration

  def up do
    alter table(:trait_categories) do
      add :exclusive_hard, :boolean, default: false, null: false
    end

    flush()

    execute(
      "UPDATE trait_categories SET exclusive_hard = true WHERE name IN ('Relationship Status', 'What I''m Looking For')"
    )

    # Clean up Divorced and Widowed flags (removed from seed migration)
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT f.id FROM trait_flags f
      JOIN trait_categories c ON c.id = f.category_id
      WHERE c.name = 'Relationship Status'
        AND f.name IN ('Divorced', 'Widowed')
    )
    """)

    execute("""
    DELETE FROM trait_flags
    WHERE category_id IN (
      SELECT id FROM trait_categories WHERE name = 'Relationship Status'
    )
    AND name IN ('Divorced', 'Widowed')
    """)
  end

  def down do
    alter table(:trait_categories) do
      remove :exclusive_hard
    end
  end
end
