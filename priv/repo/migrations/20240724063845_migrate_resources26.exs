defmodule Animina.Repo.Migrations.MigrateResources26 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:optimized_photos, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :image_url, :text, null: false
      add :type, :text, null: false

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :user_id,
          references(:users,
            column: :id,
            name: "optimized_photos_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :photo_id,
          references(:photos,
            column: :id,
            name: "optimized_photos_photo_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )
    end
  end

  def down do
    drop table(:optimized_photos)
  end
end
