defmodule Animina.Repo.Migrations.CreateAccountSecurityEvents do
  use Ecto.Migration

  def change do
    create table(:account_security_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :undo_token_hash, :binary, null: false
      add :confirm_token_hash, :binary, null: false
      add :old_email, :string
      add :old_value, :text
      add :new_value, :text
      add :expires_at, :utc_datetime, null: false
      add :resolved_at, :utc_datetime
      add :resolution, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:account_security_events, [:user_id])
    create index(:account_security_events, [:undo_token_hash])
    create index(:account_security_events, [:confirm_token_hash])
    create index(:account_security_events, [:expires_at])
  end
end
