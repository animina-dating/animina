defmodule Animina.Repo.Migrations.CreateConversationClosures do
  use Ecto.Migration

  def change do
    create table(:conversation_closures, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :closed_by_id, references(:users, type: :binary_id), null: false
      add :other_user_id, references(:users, type: :binary_id), null: false
      add :reopened_at, :utc_datetime
      add :reopened_by_id, references(:users, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:conversation_closures, [:conversation_id, :closed_by_id])

    # Fast lookup of closed (not reopened) conversations for a user
    create index(:conversation_closures, [:closed_by_id],
             where: "reopened_at IS NULL",
             name: :conversation_closures_active_closed_by_idx
           )

    create index(:conversation_closures, [:other_user_id],
             where: "reopened_at IS NULL",
             name: :conversation_closures_active_other_user_idx
           )
  end
end
