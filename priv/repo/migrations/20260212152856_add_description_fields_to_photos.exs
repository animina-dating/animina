defmodule Animina.Repo.Migrations.AddDescriptionFieldsToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :description, :text
      add :description_generated_at, :utc_datetime
      add :description_model, :string
    end

    create index(:photos, [:state],
             where: "state = 'approved' AND description IS NULL",
             name: :photos_needing_description_index
           )
  end
end
