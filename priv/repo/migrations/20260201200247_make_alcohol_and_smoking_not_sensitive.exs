defmodule Animina.Repo.Migrations.MakeAlcoholAndSmokingNotSensitive do
  use Ecto.Migration

  def up do
    execute """
    UPDATE trait_categories SET sensitive = false WHERE name IN ('Alcohol', 'Smoking')
    """
  end

  def down do
    execute """
    UPDATE trait_categories SET sensitive = true WHERE name IN ('Alcohol', 'Smoking')
    """
  end
end
