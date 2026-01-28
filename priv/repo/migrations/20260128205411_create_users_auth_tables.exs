defmodule Animina.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime

      # Profile fields
      add :display_name, :string, null: false
      add :birthday, :date, null: false
      add :gender, :string, null: false
      add :height, :integer, null: false
      add :zip_code, :string, null: false
      add :mobile_phone, :string, null: false
      add :country_id, references(:countries, type: :binary_id, on_delete: :nothing), null: false

      # Partner preferences (auto-filled, editable)
      add :preferred_partner_gender, :string
      add :partner_minimum_age_offset, :integer, default: 6
      add :partner_maximum_age_offset, :integer, default: 2
      add :partner_height_min, :integer, default: 80
      add :partner_height_max, :integer, default: 225
      add :search_radius, :integer, default: 60

      # Additional fields
      add :terms_accepted_at, :utc_datetime
      add :occupation, :string
      add :language, :string, default: "de"
      add :state, :string, null: false, default: "waitlisted"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:mobile_phone])
    create index(:users, [:country_id])
    create index(:users, [:zip_code])
    create index(:users, [:state])

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
