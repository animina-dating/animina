defmodule Animina.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  def change do
    create table(:page_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :session_id, :string, null: false
      add :path, :string, null: false
      add :referrer_path, :string
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:page_views, [:inserted_at])
    create index(:page_views, [:path, :inserted_at])
    create index(:page_views, [:user_id, :inserted_at])
    create index(:page_views, [:session_id, :inserted_at])
  end
end
