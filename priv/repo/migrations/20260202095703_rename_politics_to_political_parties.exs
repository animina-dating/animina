defmodule Animina.Repo.Migrations.RenamePoliticsToPoliticalParties do
  use Ecto.Migration

  def up do
    execute(
      "UPDATE trait_categories SET name = 'Political Parties', selection_mode = 'multi' WHERE name = 'Politics'"
    )
  end

  def down do
    execute(
      "UPDATE trait_categories SET name = 'Politics', selection_mode = 'single' WHERE name = 'Political Parties'"
    )
  end
end
