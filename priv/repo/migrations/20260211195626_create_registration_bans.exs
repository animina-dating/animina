defmodule Animina.Repo.Migrations.CreateRegistrationBans do
  use Ecto.Migration

  def change do
    create table(:registration_bans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ban_type, :string, null: false
      add :hash_value, :string, null: false

      add :report_id, references(:user_reports, type: :binary_id, on_delete: :restrict),
        null: false

      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:registration_bans, [:ban_type, :hash_value])
    create index(:registration_bans, [:hash_value])
  end
end
