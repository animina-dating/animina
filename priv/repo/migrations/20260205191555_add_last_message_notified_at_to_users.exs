defmodule Animina.Repo.Migrations.AddLastMessageNotifiedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_message_notified_at, :utc_datetime
    end
  end
end
