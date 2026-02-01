defmodule Animina.Repo.Migrations.CreateUserRoles do
  use Ecto.Migration

  def change do
    create table(:user_roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_roles, [:user_id, :role])
    create index(:user_roles, [:role])

    create constraint(:user_roles, :valid_role, check: "role IN ('moderator', 'admin')")
  end
end
