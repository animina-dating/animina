defmodule Animina.Repo.Migrations.MigrateResources9 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:reactions, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :name, :text, null: false
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")

      add :sender_id,
          references(:users,
            column: :id,
            name: "reactions_sender_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :receiver_id,
          references(:users,
            column: :id,
            name: "reactions_receiver_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create unique_index(:reactions, [:sender_id, :receiver_id, :name],
             name: "reactions_unique_reaction_index"
           )
  end

  def down do
    drop_if_exists unique_index(:reactions, [:sender_id, :receiver_id, :name],
                     name: "reactions_unique_reaction_index"
                   )

    drop constraint(:reactions, "reactions_sender_id_fkey")

    drop constraint(:reactions, "reactions_receiver_id_fkey")

    drop table(:reactions)
  end
end