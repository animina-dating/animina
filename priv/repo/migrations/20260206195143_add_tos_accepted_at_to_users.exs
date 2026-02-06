defmodule Animina.Repo.Migrations.AddTosAcceptedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tos_accepted_at, :utc_datetime
    end
  end
end
