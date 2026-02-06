defmodule Animina.Repo.Migrations.CreateUserSuggestionViews do
  use Ecto.Migration

  def change do
    create table(:user_suggestion_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :viewer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :suggested_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :list_type, :string, null: false
      add :shown_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_suggestion_views, [:viewer_id, :suggested_id, :list_type])
    create index(:user_suggestion_views, [:viewer_id, :shown_at])
    create index(:user_suggestion_views, [:suggested_id])
  end
end
