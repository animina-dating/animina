defmodule Animina.Repo.Migrations.RenameMoodboardColumnsToGridColumns do
  use Ecto.Migration

  def change do
    rename table(:users), :moodboard_columns_mobile, to: :grid_columns_mobile
    rename table(:users), :moodboard_columns_tablet, to: :grid_columns_tablet
    rename table(:users), :moodboard_columns_desktop, to: :grid_columns_desktop
  end
end
