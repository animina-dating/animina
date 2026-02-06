defmodule Animina.Repo.Migrations.DropUserFlagsWeight do
  use Ecto.Migration

  def change do
    alter table(:user_flags) do
      remove :weight, :integer
    end
  end
end
