defmodule Animina.Repo.Migrations.CreateConversationParticipants do
  use Ecto.Migration

  def change do
    create table(:conversation_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :last_read_at, :utc_datetime
      add :blocked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Each user can only be in a conversation once
    create unique_index(:conversation_participants, [:conversation_id, :user_id])

    # Fast lookup for user's conversations
    create index(:conversation_participants, [:user_id])
  end
end
