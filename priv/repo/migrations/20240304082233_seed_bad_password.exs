defmodule Animina.Repo.Migrations.SeedBadPassword do
  @moduledoc """
  Seeds bad passwords.
  """

  use Ecto.Migration

  def up do
    seed_bad_passwords()
  end

  def down do
  end

  defp seed_bad_passwords() do
    file_path = Path.join(Application.app_dir(:animina, "priv/repo"), "bad-passwords.txt")
    stream = File.stream!(file_path)

    stream
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn password -> %{value: password} end)
    |> Animina.Narratives.bulk_create(Animina.Accounts.BadPassword, :create,
      return_stream?: false,
      return_records?: false,
      batch_size: 20000
    )
  end
end
