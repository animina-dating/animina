defmodule Animina.Repo.Migrations.AddRegenerationCountToWingmanSuggestions do
  use Ecto.Migration

  def change do
    alter table(:wingman_suggestions) do
      add :regeneration_count, :integer, default: 0, null: false
    end
  end
end
