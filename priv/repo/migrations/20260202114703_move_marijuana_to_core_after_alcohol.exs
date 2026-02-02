defmodule Animina.Repo.Migrations.MoveMarijuanaToCoreAfterAlcohol do
  use Ecto.Migration

  def up do
    # Bump positions 10+ up by 1 to make room after Alcohol (position 9)
    execute("""
    UPDATE trait_categories SET position = position + 1
    WHERE position >= 10 AND name != 'Marijuana'
    """)

    # Set Marijuana to core, remove picker_group, position 10
    execute("""
    UPDATE trait_categories
    SET core = true, picker_group = NULL, position = 10
    WHERE name = 'Marijuana'
    """)
  end

  def down do
    # Move Marijuana back to sensitive picker group at position 21
    execute("""
    UPDATE trait_categories
    SET core = false, picker_group = 'sensitive', position = 21
    WHERE name = 'Marijuana'
    """)

    # Shift positions 11+ back down by 1
    execute("""
    UPDATE trait_categories SET position = position - 1
    WHERE position >= 11 AND name != 'Marijuana'
    """)
  end
end
