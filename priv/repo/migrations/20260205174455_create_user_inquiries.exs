defmodule Animina.Repo.Migrations.CreateUserInquiries do
  use Ecto.Migration

  def change do
    create table(:user_inquiries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :receiver_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :inquiry_date, :date, null: false

      timestamps(type: :utc_datetime)
    end

    # One inquiry per sender-receiver pair
    create unique_index(:user_inquiries, [:sender_id, :receiver_id])

    # Fast lookup for daily count queries
    create index(:user_inquiries, [:receiver_id, :inquiry_date])

    # For rolling window queries
    create index(:user_inquiries, [:receiver_id, :inserted_at])
  end
end
