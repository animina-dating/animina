defmodule Animina.Repo.Migrations.MigratePhotosToSubdirectories do
  use Ecto.Migration

  import Ecto.Query

  @doc """
  Moves processed photo files from the legacy flat directory structure
  to the new owner-specific subdirectory structure.

  Before: uploads/processed/{photo_id}.webp
  After:  uploads/processed/{owner_type}/{owner_id}/{photo_id}.webp
  """
  def up do
    upload_dir =
      Application.get_env(:animina, Animina.Photos, []) |> Keyword.get(:upload_dir, "uploads")

    processed_dir = Path.join(upload_dir, "processed")

    photos =
      from(p in "photos", select: %{id: p.id, owner_type: p.owner_type, owner_id: p.owner_id})
      |> repo().all()

    moved =
      Enum.count(photos, fn photo ->
        photo_id = dump_uuid(photo.id)
        owner_type = photo.owner_type
        owner_id = dump_uuid(photo.owner_id)

        target_dir = Path.join([processed_dir, owner_type, owner_id])

        moved_any =
          Enum.reduce(["#{photo_id}.webp", "#{photo_id}_thumb.webp"], false, fn filename, acc ->
            old_path = Path.join(processed_dir, filename)
            new_path = Path.join(target_dir, filename)

            if File.exists?(old_path) and not File.exists?(new_path) do
              File.mkdir_p!(target_dir)
              File.cp!(old_path, new_path)
              File.rm!(old_path)
              true
            else
              acc
            end
          end)

        moved_any
      end)

    if moved > 0 do
      IO.puts("Migrated #{moved} photo(s) to subdirectory structure")
    end
  end

  def down do
    upload_dir =
      Application.get_env(:animina, Animina.Photos, []) |> Keyword.get(:upload_dir, "uploads")

    processed_dir = Path.join(upload_dir, "processed")

    photos =
      from(p in "photos", select: %{id: p.id, owner_type: p.owner_type, owner_id: p.owner_id})
      |> repo().all()

    Enum.each(photos, fn photo ->
      photo_id = dump_uuid(photo.id)
      owner_type = photo.owner_type
      owner_id = dump_uuid(photo.owner_id)

      target_dir = Path.join([processed_dir, owner_type, owner_id])

      for filename <- ["#{photo_id}.webp", "#{photo_id}_thumb.webp"] do
        new_path = Path.join(target_dir, filename)
        old_path = Path.join(processed_dir, filename)

        if File.exists?(new_path) and not File.exists?(old_path) do
          File.cp!(new_path, old_path)
          File.rm!(new_path)
        end
      end
    end)
  end

  # binary_id columns come back as raw 16-byte binaries from schemaless queries
  defp dump_uuid(<<_::128>> = bin), do: Ecto.UUID.load!(bin)
  defp dump_uuid(str) when is_binary(str), do: str
end
