defmodule Animina.Repo.Migrations.RemoveWingmanStyleAndRegenerationCount do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :wingman_style, :string, default: "casual"
    end

    alter table(:wingman_suggestions) do
      remove :regeneration_count, :integer, default: 0
    end
  end
end
