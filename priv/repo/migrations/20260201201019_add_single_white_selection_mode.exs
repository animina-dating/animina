defmodule Animina.Repo.Migrations.AddSingleWhiteSelectionMode do
  use Ecto.Migration

  def up do
    # Expand the check constraint to allow 'single_white'
    drop constraint(:trait_categories, :valid_selection_mode)

    create constraint(:trait_categories, :valid_selection_mode,
             check: "selection_mode IN ('multi', 'single', 'single_white')"
           )

    # Alcohol, Smoking, Marijuana: single for white, multi for green/red
    execute """
    UPDATE trait_categories
    SET selection_mode = 'single_white'
    WHERE name IN ('Alcohol', 'Smoking', 'Marijuana')
    """
  end

  def down do
    execute """
    UPDATE trait_categories
    SET selection_mode = 'single'
    WHERE name IN ('Alcohol', 'Smoking', 'Marijuana')
    """

    drop constraint(:trait_categories, :valid_selection_mode)

    create constraint(:trait_categories, :valid_selection_mode,
             check: "selection_mode IN ('multi', 'single')"
           )
  end
end
