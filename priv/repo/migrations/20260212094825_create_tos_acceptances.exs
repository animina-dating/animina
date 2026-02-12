defmodule Animina.Repo.Migrations.CreateTosAcceptances do
  use Ecto.Migration

  def change do
    create table(:tos_acceptances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :version, :string, null: false
      add :accepted_at, :utc_datetime, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:tos_acceptances, [:user_id])
    create index(:tos_acceptances, [:version])
  end
end
