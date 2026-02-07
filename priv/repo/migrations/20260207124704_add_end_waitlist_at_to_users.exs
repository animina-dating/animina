defmodule Animina.Repo.Migrations.AddEndWaitlistAtToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :end_waitlist_at, :utc_datetime
    end

    # Backfill: existing waitlisted users get inserted_at + 28 days
    execute """
    UPDATE users
    SET end_waitlist_at = inserted_at + INTERVAL '28 days'
    WHERE state = 'waitlisted' AND end_waitlist_at IS NULL
    """
  end

  def down do
    alter table(:users) do
      remove :end_waitlist_at
    end
  end
end
