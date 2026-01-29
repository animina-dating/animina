defmodule Animina.Repo.Migrations.CreateUserLocations do
  use Ecto.Migration

  def up do
    create table(:user_locations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :country_id, references(:countries, type: :binary_id), null: false
      add :zip_code, :string, null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_locations, [:user_id, :position])
    create unique_index(:user_locations, [:user_id, :zip_code])
    create index(:user_locations, [:zip_code])

    # Migrate existing data from users table
    execute """
    INSERT INTO user_locations (id, user_id, country_id, zip_code, position, inserted_at, updated_at)
    SELECT gen_random_uuid(), id, country_id, zip_code, 1, NOW(), NOW()
    FROM users
    WHERE zip_code IS NOT NULL AND country_id IS NOT NULL
    """

    alter table(:users) do
      remove :zip_code
      remove :country_id
    end
  end

  def down do
    alter table(:users) do
      add :zip_code, :string
      add :country_id, references(:countries, type: :binary_id)
    end

    # Migrate data back from user_locations to users (only position 1)
    execute """
    UPDATE users SET zip_code = ul.zip_code, country_id = ul.country_id
    FROM user_locations ul
    WHERE ul.user_id = users.id AND ul.position = 1
    """

    drop table(:user_locations)
  end
end
