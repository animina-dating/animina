defmodule Animina.Repo.Migrations.CreateUserOnlineSessions do
  use Ecto.Migration

  def change do
    create table(:user_online_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :duration_minutes, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:user_online_sessions, [:user_id, :started_at])
    create index(:user_online_sessions, [:started_at])

    # Partial index for fast open session lookup
    create index(:user_online_sessions, [:user_id],
             where: "ended_at IS NULL",
             name: :user_online_sessions_open_index
           )
  end
end
