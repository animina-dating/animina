defmodule Animina.MigratePhotosToSubdirectoriesTest do
  use Animina.DataCase, async: false

  alias Animina.Photos

  import Animina.PhotosFixtures

  describe "migrate_photos_to_subdirectories" do
    test "moves files from flat directory to owner subdirectory" do
      photo = approved_photo_fixture(%{owner_type: "User", owner_id: Ecto.UUID.generate()})

      # Create files at the legacy flat path
      {legacy_main, legacy_thumb} = create_legacy_processed_files(photo)
      assert File.exists?(legacy_main)
      assert File.exists?(legacy_thumb)

      # New paths should not exist yet
      new_main = Photos.processed_path(photo, :main)
      new_thumb = Photos.processed_path(photo, :thumbnail)
      refute File.exists?(new_main)
      refute File.exists?(new_thumb)

      # Run the migration logic
      migrate_photos_up()

      # Files should now be at the new paths
      assert File.exists?(new_main)
      assert File.exists?(new_thumb)

      # Legacy paths should be gone
      refute File.exists?(legacy_main)
      refute File.exists?(legacy_thumb)
    after
      File.rm_rf!(Photos.processed_dir())
    end

    test "skips photos already at the new path" do
      photo = approved_photo_fixture(%{owner_type: "User", owner_id: Ecto.UUID.generate()})

      # Create files at both locations
      create_legacy_processed_files(photo)
      create_processed_files(photo)

      new_main = Photos.processed_path(photo, :main)
      original_content = File.read!(new_main)

      # Run migration - should not overwrite existing files
      migrate_photos_up()

      assert File.read!(new_main) == original_content
    after
      File.rm_rf!(Photos.processed_dir())
    end

    test "handles MoodboardItem owner type" do
      item_id = Ecto.UUID.generate()
      photo = approved_photo_fixture(%{owner_type: "MoodboardItem", owner_id: item_id})

      create_legacy_processed_files(photo)

      migrate_photos_up()

      new_main = Photos.processed_path(photo, :main)
      assert File.exists?(new_main)
      assert String.contains?(new_main, "MoodboardItem/#{item_id}")
    after
      File.rm_rf!(Photos.processed_dir())
    end
  end

  # Runs the up/0 migration logic directly
  defp migrate_photos_up do
    import Ecto.Query

    upload_dir =
      Application.get_env(:animina, Animina.Photos, []) |> Keyword.get(:upload_dir, "uploads")

    processed_dir = Path.join(upload_dir, "processed")

    photos =
      from(p in "photos", select: %{id: p.id, owner_type: p.owner_type, owner_id: p.owner_id})
      |> Animina.Repo.all()

    photos
    |> Enum.flat_map(&legacy_file_pairs(&1, processed_dir))
    |> Enum.each(fn {old_path, new_path, target_dir} ->
      if File.exists?(old_path) and not File.exists?(new_path) do
        File.mkdir_p!(target_dir)
        File.cp!(old_path, new_path)
        File.rm!(old_path)
      end
    end)
  end

  defp legacy_file_pairs(photo, processed_dir) do
    photo_id = dump_uuid(photo.id)
    target_dir = Path.join([processed_dir, photo.owner_type, dump_uuid(photo.owner_id)])

    Enum.map(["#{photo_id}.webp", "#{photo_id}_thumb.webp"], fn filename ->
      {Path.join(processed_dir, filename), Path.join(target_dir, filename), target_dir}
    end)
  end

  defp dump_uuid(<<_::128>> = bin), do: Ecto.UUID.load!(bin)
  defp dump_uuid(str) when is_binary(str), do: str
end
