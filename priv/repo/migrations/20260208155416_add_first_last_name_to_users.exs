defmodule Animina.Repo.Migrations.AddFirstLastNameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :first_name, :string, null: false, default: ""
      add :last_name, :string, null: false, default: ""
    end
  end
end
