defmodule Animina.Repo.Migrations.MigrateResources6 do
    @moduledoc """
    Updates resources based on their most recent snapshots.
    """

    use Ecto.Migration

    def change do

     execute """
     UPDATE users
     SET registration_completed_at = '2024-08-22 09:00:00+00';
     """
    end


end
