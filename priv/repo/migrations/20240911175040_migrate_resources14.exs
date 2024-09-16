defmodule Animina.Repo.Migrations.MigrateResources14 do
  @moduledoc """
  Updates resources based on their most recent snapshots.
  """

  use Ecto.Migration

  def up do
    # Update the users' state from 'incognito' to 'hibernate'
    execute "UPDATE users SET state = 'hibernate' WHERE state = 'incognito';"
  end

  def down do
    # Revert the changes, setting 'hibernate' back to 'incognito'
    execute "UPDATE users SET state = 'incognito' WHERE state = 'hibernate';"
  end

end
