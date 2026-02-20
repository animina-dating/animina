defmodule Animina.Repo.Migrations.AddWingmanStyleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :wingman_style, :string, default: "casual", null: false
    end
  end
end
