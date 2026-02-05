defmodule Animina.Repo.Migrations.AddMoodboardColumnPreferences do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :moodboard_columns_mobile, :integer, default: 2
      add :moodboard_columns_tablet, :integer, default: 2
      add :moodboard_columns_desktop, :integer, default: 3
    end
  end
end
