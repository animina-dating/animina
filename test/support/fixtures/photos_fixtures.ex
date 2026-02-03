defmodule Animina.PhotosFixtures do
  @moduledoc """
  Test helpers for creating photo entities.
  """

  alias Animina.Photos
  alias Animina.Photos.PhotoAppeal
  alias Animina.Repo

  @doc """
  Creates a test image file using the Image library and returns the path.
  """
  def create_test_image(dir \\ nil) do
    dir = dir || System.tmp_dir!()
    path = Path.join(dir, "test_#{System.unique_integer([:positive])}.png")

    # Create a 100x100 solid color image via Image/Vix
    {:ok, image} = Image.new(100, 100, color: :red)
    {:ok, _} = Image.write(image, path)

    path
  end

  @doc """
  Creates a photo record directly in the database (bypassing file upload).
  """
  def photo_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        owner_type: "User",
        owner_id: Ecto.UUID.generate(),
        filename: Ecto.UUID.generate(),
        original_filename: "test.jpg",
        content_type: "image/jpeg",
        state: "pending"
      })

    {:ok, photo} = Photos.create_photo(attrs)
    photo
  end

  @doc """
  Creates an approved photo record.
  """
  def approved_photo_fixture(attrs \\ %{}) do
    photo = photo_fixture(attrs)

    photo
    |> Ecto.Changeset.change(%{state: "approved", width: 800, height: 600})
    |> Repo.update!()
  end

  @doc """
  Creates an approved NSFW photo record.
  """
  def nsfw_photo_fixture(attrs \\ %{}) do
    photo = photo_fixture(attrs)

    photo
    |> Ecto.Changeset.change(%{
      state: "approved",
      width: 800,
      height: 600,
      nsfw: true,
      nsfw_score: 0.95
    })
    |> Repo.update!()
  end

  @doc """
  Creates a photo in ollama_checking state (processing complete, awaiting Ollama check).
  """
  def ollama_checking_photo_fixture(attrs \\ %{}) do
    photo = photo_fixture(attrs)

    photo
    |> Ecto.Changeset.change(%{state: "ollama_checking", width: 800, height: 600})
    |> Repo.update!()
  end

  @doc """
  Creates a photo in no_face_error state (face detection failed).
  """
  def no_face_error_photo_fixture(attrs \\ %{}) do
    photo = photo_fixture(attrs)

    photo
    |> Ecto.Changeset.change(%{
      state: "no_face_error",
      width: 800,
      height: 600,
      nsfw: false,
      has_face: false,
      face_score: 0.1,
      error_message: "No face detected in photo"
    })
    |> Repo.update!()
  end

  @doc """
  Creates a photo in appeal_pending state.
  """
  def appeal_pending_photo_fixture(attrs \\ %{}) do
    photo = photo_fixture(attrs)

    update_attrs =
      %{
        state: "appeal_pending",
        width: 800,
        height: 600,
        nsfw: false,
        has_face: false,
        face_score: 0.1,
        error_message: "No face detected in photo"
      }
      |> maybe_add_dhash(attrs)

    photo
    |> Ecto.Changeset.change(update_attrs)
    |> Repo.update!()
  end

  defp maybe_add_dhash(update_attrs, attrs) do
    case Map.get(attrs, :dhash) do
      nil -> update_attrs
      dhash -> Map.put(update_attrs, :dhash, dhash)
    end
  end

  @doc """
  Creates a photo in error state.
  """
  def error_photo_fixture(attrs \\ %{}) do
    photo = photo_fixture(attrs)

    photo
    |> Ecto.Changeset.change(%{
      state: "error",
      error_message: "Processing failed"
    })
    |> Repo.update!()
  end

  @doc """
  Creates a photo appeal for a photo in appeal_pending state.
  Requires a user_id to be provided.
  """
  def appeal_fixture(attrs \\ %{}) do
    user_id = Map.get(attrs, :user_id) || raise "user_id is required for appeal_fixture"

    photo_attrs =
      attrs
      |> Map.take([:owner_type, :owner_id, :dhash])
      |> Map.put_new(:owner_id, user_id)

    photo = appeal_pending_photo_fixture(photo_attrs)

    appeal_attrs = %{
      photo_id: photo.id,
      user_id: user_id,
      appeal_reason: Map.get(attrs, :appeal_reason, "Please review my photo")
    }

    {:ok, appeal} =
      %PhotoAppeal{}
      |> PhotoAppeal.create_changeset(appeal_attrs)
      |> Repo.insert()

    appeal |> Repo.preload([:photo, :user])
  end

  @doc """
  Creates dummy processed WebP files for a photo so the controller can serve it.
  """
  def create_processed_files(photo) do
    dir = Photos.processed_dir()
    File.mkdir_p!(dir)

    main_path = Photos.processed_path(photo.id, :main)
    pixelated_path = Photos.processed_path(photo.id, :pixelated)
    thumbnail_path = Photos.processed_path(photo.id, :thumbnail)

    # Write minimal valid WebP files (RIFF header + WEBP chunk with minimal VP8 data)
    webp_data = create_minimal_webp()
    File.write!(main_path, webp_data)
    File.write!(pixelated_path, webp_data)
    File.write!(thumbnail_path, webp_data)

    {main_path, pixelated_path, thumbnail_path}
  end

  defp create_minimal_webp do
    # Minimal WebP file: RIFF header + WEBP + VP8 lossy chunk
    # This is a valid 1x1 WebP image
    vp8_data =
      <<0x9D, 0x01, 0x2A, 0x01, 0x00, 0x01, 0x00, 0x01, 0x40, 0x25, 0xA4, 0x00, 0x03, 0x70, 0x00,
        0xFE, 0xFB, 0x94, 0x00, 0x00>>

    chunk_size = byte_size(vp8_data)
    file_size = 4 + 8 + chunk_size

    <<"RIFF", file_size::little-32, "WEBP", "VP8 ", chunk_size::little-32, vp8_data::binary>>
  end
end
