defmodule Animina.Repo.Migrations.SeedRoles do
  @moduledoc """
  Seeds roles
  """

  use Ecto.Migration

  def up do
    seed_roles()
  end

  def down do
  end

  defp seed_roles do
    roles()
    |> Ash.bulk_create(Animina.Accounts.Role, :create,
      return_stream?: false,
      return_records?: false,
      batch_size: 100
    )
  end

  defp roles do
    [
      %{name: :user},
      %{name: :admin}
    ]
  end
end
