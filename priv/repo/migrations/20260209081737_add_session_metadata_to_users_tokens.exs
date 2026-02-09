defmodule Animina.Repo.Migrations.AddSessionMetadataToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :user_agent, :text
      add :ip_address, :string, size: 45
      add :last_seen_at, :utc_datetime
    end
  end
end
