defmodule Animina.Repo.Migrations.AddSuspensionBanFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :suspended_until, :utc_datetime
      add :ban_reason, :text
    end

    create index(:users, [:state, :suspended_until])
  end
end
