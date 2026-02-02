defmodule Animina.Repo.Migrations.CreateOnlineUserCounts do
  use Ecto.Migration

  def change do
    create table(:online_user_counts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :count, :integer, null: false
      add :recorded_at, :utc_datetime, null: false
    end

    create index(:online_user_counts, [:recorded_at])
  end
end
