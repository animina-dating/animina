defmodule Animina.Repo.Migrations.AddDraftsToConversationParticipants do
  use Ecto.Migration

  def change do
    alter table(:conversation_participants) do
      add :draft_content, :text
      add :draft_updated_at, :utc_datetime
    end
  end
end
