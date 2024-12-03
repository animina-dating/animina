defmodule Animina.Repo.Migrations.SeedBadPassword do
  @moduledoc """
  Seeds bad passwords.
  """

  use Ecto.Migration

  def up do
    # Don't seed bad passwords in CI to speed up the workflow.
    unless System.get_env("CI") do
      seed_bad_passwords()
    end
  end

  def down do
  end

  defp seed_bad_passwords() do
    file_path = Path.join(Application.app_dir(:animina, "priv/repo"), "bad-passwords.txt")

    # In :dev, :test and CI only use the first 10 passwords to speed up the workflow.
    stream =
      if Enum.member?([:dev, :test], Application.get_env(:animina, :environment)) or System.get_env("CI") do
        File.stream!(file_path)
        |> Stream.take(10)
      else
        File.stream!(file_path)
      end

    stream
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn password -> %{value: password} end)
    |> Ash.bulk_create(Animina.Accounts.BadPassword, :create,
      return_stream?: false,
      return_records?: false,
      batch_size: 20000
    )
  end
end
