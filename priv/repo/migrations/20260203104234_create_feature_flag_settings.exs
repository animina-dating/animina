defmodule Animina.Repo.Migrations.CreateFeatureFlagSettings do
  use Ecto.Migration

  def change do
    create table(:feature_flag_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flag_name, :string, null: false
      add :description, :text
      add :settings, :map, default: %{}

      timestamps()
    end

    create unique_index(:feature_flag_settings, [:flag_name])
  end
end
