defmodule Animina.Repo.Migrations.CreateProfileVisits do
  use Ecto.Migration

  def change do
    create table(:profile_visits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :visitor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :visited_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profile_visits, [:visitor_id, :visited_id])
    create index(:profile_visits, [:visited_id])
  end
end
