defmodule Animina.Photos.FileManagementTest do
  use Animina.DataCase, async: true

  alias Animina.Photos
  alias Animina.Photos.FileManagement

  import Animina.PhotosFixtures

  describe "generate_pixel_variant/1" do
    test "generates a pixelated WebP file from the main variant" do
      photo = approved_photo_fixture()

      # Create a real main variant using the Image library
      dir = Photos.processed_path_dir(photo.owner_type, photo.owner_id)
      File.mkdir_p!(dir)

      main_path = Photos.processed_path(photo, :main)
      {:ok, image} = Image.new(100, 100, color: :blue)
      {:ok, _} = Image.write(image, main_path)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      assert :ok = FileManagement.generate_pixel_variant(photo)

      pixel_path = Photos.processed_path(photo, :pixel)
      assert File.exists?(pixel_path)
    end

    test "is idempotent — skips if pixel file already exists" do
      photo = approved_photo_fixture()

      dir = Photos.processed_path_dir(photo.owner_type, photo.owner_id)
      File.mkdir_p!(dir)

      # Create main variant
      main_path = Photos.processed_path(photo, :main)
      {:ok, image} = Image.new(100, 100, color: :red)
      {:ok, _} = Image.write(image, main_path)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      # Generate once
      assert :ok = FileManagement.generate_pixel_variant(photo)

      # Record modification time
      pixel_path = Photos.processed_path(photo, :pixel)
      {:ok, %{mtime: mtime1}} = File.stat(pixel_path)

      # Small delay to ensure mtime would differ
      Process.sleep(10)

      # Generate again — should skip
      assert :ok = FileManagement.generate_pixel_variant(photo)
      {:ok, %{mtime: mtime2}} = File.stat(pixel_path)

      assert mtime1 == mtime2
    end

    test "returns error when main variant is missing" do
      photo = approved_photo_fixture()

      # Don't create any files
      assert {:error, :main_not_found} = FileManagement.generate_pixel_variant(photo)
    end
  end

  describe "generate_review_pixel_variant/1" do
    test "generates a heavily pixelated WebP file from the main variant" do
      photo = approved_photo_fixture()

      dir = Photos.processed_path_dir(photo.owner_type, photo.owner_id)
      File.mkdir_p!(dir)

      main_path = Photos.processed_path(photo, :main)
      {:ok, image} = Image.new(100, 100, color: :green)
      {:ok, _} = Image.write(image, main_path)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      assert :ok = FileManagement.generate_review_pixel_variant(photo)

      review_pixel_path = Photos.processed_path(photo, :review_pixel)
      assert File.exists?(review_pixel_path)
    end

    test "is idempotent — skips if review_pixel file already exists" do
      photo = approved_photo_fixture()

      dir = Photos.processed_path_dir(photo.owner_type, photo.owner_id)
      File.mkdir_p!(dir)

      main_path = Photos.processed_path(photo, :main)
      {:ok, image} = Image.new(100, 100, color: :red)
      {:ok, _} = Image.write(image, main_path)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      # Generate once
      assert :ok = FileManagement.generate_review_pixel_variant(photo)

      review_pixel_path = Photos.processed_path(photo, :review_pixel)
      {:ok, %{mtime: mtime1}} = File.stat(review_pixel_path)

      Process.sleep(10)

      # Generate again — should skip
      assert :ok = FileManagement.generate_review_pixel_variant(photo)
      {:ok, %{mtime: mtime2}} = File.stat(review_pixel_path)

      assert mtime1 == mtime2
    end

    test "returns error when main variant is missing" do
      photo = approved_photo_fixture()

      assert {:error, :main_not_found} = FileManagement.generate_review_pixel_variant(photo)
    end
  end

  describe "generate_review_pixel_from_image/2" do
    test "generates review pixel from an already-loaded image" do
      photo = approved_photo_fixture()

      dir = Photos.processed_path_dir(photo.owner_type, photo.owner_id)
      File.mkdir_p!(dir)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      {:ok, image} = Image.new(200, 200, color: :blue)

      assert :ok = FileManagement.generate_review_pixel_from_image(photo, image)

      review_pixel_path = Photos.processed_path(photo, :review_pixel)
      assert File.exists?(review_pixel_path)
    end
  end
end
