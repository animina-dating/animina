defmodule AshBlog.Repo.Migrations.AddMessages do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:messages, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :content, :string, null: false
      add :read_at, :utc_datetime_usec

      add :sender_id,
          references(:users,
            column: :id,
            name: "messages_sender_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :receiver_id,
          references(:users,
            column: :id,
            name: "messages_receiver_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:messages, [:sender_id, :receiver_id],
             name: "messages_unique_sender_receiver_index"
           )
  end

  def down do
    drop_if_exists unique_index(:messages, [:sender_id, :receiver_id],
                     name: "messages_unique_sender_receiver_index"
                   )

    drop constraint(:messages, "messages_sender_id_fkey")
    drop constraint(:messages, "messages_receiver_id_fkey")
    drop table(:messages)
  end
end
