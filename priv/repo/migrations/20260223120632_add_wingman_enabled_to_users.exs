defmodule Animina.Repo.Migrations.AddWingmanEnabledToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :wingman_enabled, :boolean, default: true, null: false
    end
  end
end
