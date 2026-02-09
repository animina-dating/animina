defmodule Animina.Repo.Migrations.CreateEmailLogs do
  use Ecto.Migration

  def change do
    create table(:email_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :email_type, :string, null: false
      add :recipient, :string, null: false
      add :subject, :string, null: false
      add :body, :text, null: false
      add :status, :string, null: false
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create index(:email_logs, [:inserted_at])
    create index(:email_logs, [:user_id])
    create index(:email_logs, [:email_type])
    create index(:email_logs, [:status])
  end
end
