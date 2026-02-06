defmodule Animina.Repo.Migrations.CreateUserCategoryImportances do
  use Ecto.Migration

  def change do
    alter table(:user_flags) do
      add :weight, :integer
    end
  end
end
