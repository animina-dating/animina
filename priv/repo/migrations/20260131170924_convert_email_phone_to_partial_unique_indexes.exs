defmodule Animina.Repo.Migrations.ConvertEmailPhoneToPartialUniqueIndexes do
  use Ecto.Migration

  def change do
    # Drop full unique indexes
    drop unique_index(:users, [:email])
    drop unique_index(:users, [:mobile_phone])

    # Create partial unique indexes that only enforce for active (non-deleted) users
    create unique_index(:users, [:email],
             where: "deleted_at IS NULL",
             name: :users_email_active_index
           )

    create unique_index(:users, [:mobile_phone],
             where: "deleted_at IS NULL",
             name: :users_mobile_phone_active_index
           )
  end
end
