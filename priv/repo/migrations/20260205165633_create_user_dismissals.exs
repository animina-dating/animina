defmodule Animina.Repo.Migrations.CreateUserDismissals do
  use Ecto.Migration

  def change do
    create table(:user_dismissals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :dismissed_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_dismissals, [:user_id, :dismissed_id])
    create index(:user_dismissals, [:dismissed_id])
  end
end
