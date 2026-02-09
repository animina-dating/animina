defmodule Animina.Repo.Migrations.AddHideOnlineStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :hide_online_status, :boolean, default: false, null: false
    end
  end
end
