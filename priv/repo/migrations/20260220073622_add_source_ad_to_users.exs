defmodule Animina.Repo.Migrations.AddSourceAdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :source_ad_id, references(:ads, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:users, [:source_ad_id])
  end
end
