defmodule Animina.Repo.Migrations.RenameAnimalsToPets do
  use Ecto.Migration

  def up do
    execute("UPDATE trait_categories SET name = 'Pets' WHERE name = 'Animals'")
  end

  def down do
    execute("UPDATE trait_categories SET name = 'Animals' WHERE name = 'Pets'")
  end
end
