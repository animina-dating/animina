defmodule Animina.Repo.Migrations.AddConversationLifecycleFields do
  use Ecto.Migration

  def change do
    alter table(:conversation_participants) do
      add :closed_at, :utc_datetime
      add :initiator, :boolean, default: false, null: false
    end

    # Fast counting of active (non-closed) conversations per user
    create index(:conversation_participants, [:user_id],
             where: "closed_at IS NULL",
             name: :conversation_participants_active_user_idx
           )
  end
end
