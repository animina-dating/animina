defmodule Animina.Repo.Migrations.MigrateResources12 do
  @moduledoc """
  Updates resources based on their most recent snapshots.
  """

  use Ecto.Migration

  def change do
   execute """
   UPDATE users
   SET country = 'Germany'
   """
  end

end
