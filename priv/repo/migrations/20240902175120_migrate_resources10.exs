defmodule Animina.Repo.Migrations.MigrateResources10 do
  use Ecto.Migration

  def up do
    drop table(:photo_tags)
    drop table(:photo_flag_tags)
  end

  def down do
    create table(:photo_flag_tags, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :description, :text

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :user_id,
          references(:users,
            column: :id,
            name: "photo_flag_tags_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :photo_id,
          references(:photos,
            column: :id,
            name: "photo_flag_tags_photo_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :flag_id,
          references(:traits_flags,
            column: :id,
            name: "photo_flag_tags_flag_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )
    end

    create table(:photo_tags, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :description, :text

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :user_id,
          references(:users,
            column: :id,
            name: "photo_tags_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :photo_id,
          references(:photos,
            column: :id,
            name: "photo_tags_photo_id_fkey",
            type: :uuid,
            prefix: "public"
          )
    end
  end
end
