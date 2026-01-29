defmodule Animina.Repo.Migrations.AddConfirmationPinToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :confirmation_pin_hash, :string
      add :confirmation_pin_attempts, :integer, default: 0, null: false
      add :confirmation_pin_sent_at, :utc_datetime
    end
  end
end
