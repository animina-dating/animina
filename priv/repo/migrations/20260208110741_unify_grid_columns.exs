defmodule Animina.Repo.Migrations.UnifyGridColumns do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :grid_columns, :integer, default: 2
    end

    # Copy desktop preference to the unified column
    execute(
      "UPDATE users SET grid_columns = grid_columns_desktop WHERE grid_columns_desktop IS NOT NULL",
      "UPDATE users SET grid_columns_desktop = grid_columns WHERE grid_columns IS NOT NULL"
    )

    alter table(:users) do
      remove :grid_columns_mobile, :integer, default: 2
      remove :grid_columns_tablet, :integer, default: 2
      remove :grid_columns_desktop, :integer, default: 3
    end
  end
end
