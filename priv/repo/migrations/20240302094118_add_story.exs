defmodule Animina.Repo.Migrations.AddStory do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:stories, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :content, :text, null: false
      add :position, :bigint, null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "stories_user_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :headline_id,
          references(:headlines,
            column: :id,
            name: "stories_headline_id_fkey",
            type: :uuid,
            prefix: "public"
          )
    end

    create unique_index(:stories, [:position, :user_id], name: "stories_unique_position_index")
  end

  def down do
    drop_if_exists unique_index(:stories, [:position, :user_id],
                     name: "stories_unique_position_index"
                   )

    drop constraint(:stories, "stories_user_id_fkey")

    drop constraint(:stories, "stories_headline_id_fkey")

    drop table(:stories)
  end
end
