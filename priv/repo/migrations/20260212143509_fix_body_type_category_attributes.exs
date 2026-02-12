defmodule Animina.Repo.Migrations.FixBodyTypeCategoryAttributes do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE trait_categories
    SET core = true, sensitive = false, picker_group = NULL
    WHERE name = 'Body Type'
    """)
  end

  def down do
    execute("""
    UPDATE trait_categories
    SET core = false, sensitive = true, picker_group = 'sensitive'
    WHERE name = 'Body Type'
    """)
  end
end
