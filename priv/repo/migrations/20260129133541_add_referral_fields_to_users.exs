defmodule Animina.Repo.Migrations.AddReferralFieldsToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :referral_code, :string
      add :waitlist_priority, :integer, null: false, default: 0
      add :referred_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    flush()

    # Generate referral codes for existing users
    execute """
    UPDATE users SET referral_code = upper(substr(md5(random()::text || id::text), 1, 6))
    WHERE referral_code IS NULL
    """

    # Ensure uniqueness by appending random chars if any collisions exist
    execute """
    UPDATE users u1
    SET referral_code = upper(substr(md5(random()::text || u1.id::text || now()::text), 1, 6))
    WHERE EXISTS (
      SELECT 1 FROM users u2
      WHERE u2.referral_code = u1.referral_code AND u2.id < u1.id
    )
    """

    alter table(:users) do
      modify :referral_code, :string, null: false
    end

    create unique_index(:users, [:referral_code])
    create index(:users, [:referred_by_id])
  end

  def down do
    drop_if_exists index(:users, [:referred_by_id])
    drop_if_exists unique_index(:users, [:referral_code])

    alter table(:users) do
      remove :referral_code
      remove :waitlist_priority
      remove :referred_by_id
    end
  end
end
