defmodule Animina.Repo.Migrations.CreatePhotoAppeals do
  use Ecto.Migration

  def change do
    create table(:photo_appeals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :photo_id, references(:photos, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :appeal_reason, :text
      add :reviewer_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reviewer_notes, :text
      add :resolution, :string
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:photo_appeals, [:photo_id])
    create index(:photo_appeals, [:user_id])
    create index(:photo_appeals, [:reviewer_id])
    create index(:photo_appeals, [:status])
  end
end
