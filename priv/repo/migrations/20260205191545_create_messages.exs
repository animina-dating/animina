defmodule Animina.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :content, :text, null: false
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Fast lookup for messages in a conversation, ordered by time
    create index(:messages, [:conversation_id, :inserted_at])

    # For user's sent messages
    create index(:messages, [:sender_id])
  end
end
