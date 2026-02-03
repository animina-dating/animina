defmodule Animina.Repo.Migrations.CreatePhotos do
  use Ecto.Migration

  def change do
    create table(:photos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_type, :string, null: false
      add :owner_id, :binary_id, null: false
      add :type, :string
      add :state, :string, null: false, default: "pending"
      add :filename, :string, null: false
      add :original_filename, :string
      add :content_type, :string
      add :width, :integer
      add :height, :integer
      add :position, :integer, default: 0
      add :nsfw, :boolean, default: false
      add :nsfw_score, :float
      add :error_message, :string

      timestamps(type: :utc_datetime)
    end

    create index(:photos, [:owner_type, :owner_id])
    create index(:photos, [:owner_type, :owner_id, :type])
    create index(:photos, [:state])
  end
end
