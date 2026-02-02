defmodule Animina.Repo.Migrations.FixUserFlagsUniqueIndexIncludeColor do
  use Ecto.Migration

  def change do
    drop unique_index(:user_flags, [:user_id, :flag_id])
    create unique_index(:user_flags, [:user_id, :flag_id, :color])
  end
end
