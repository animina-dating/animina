defmodule Animina.Photos.FileManagement do
  @moduledoc """
  File management utilities for photo uploads and processing.

  Handles file validation, storage paths, and EXIF stripping.
  """

  alias Animina.Photos
  alias Animina.Photos.Photo
  alias Animina.Photos.PhotoProcessor

  @doc """
  Handles a new photo upload: validates the file, saves the original,
  creates the DB record, and enqueues background processing.

  Validates:
  - File size is within max_upload_size limit
  - File magic bytes match a supported image format (PNG, JPEG, WebP, HEIC)
  """
  def upload_photo(owner_type, owner_id, source_path, opts \\ []) do
    with :ok <- validate_file_size(source_path),
         {:ok, detected_type} <- validate_image_magic(source_path) do
      do_upload_photo(owner_type, owner_id, source_path, detected_type, opts)
    end
  end

  defp validate_file_size(file_path) do
    max_size = Photos.max_upload_size()

    case File.stat(file_path) do
      {:ok, %{size: size}} ->
        if size <= max_size, do: :ok, else: {:error, :file_too_large}

      {:error, _} ->
        {:error, :file_read_error}
    end
  end

  defp do_upload_photo(owner_type, owner_id, source_path, detected_type, opts) do
    filename = Ecto.UUID.generate()
    original_filename = Keyword.get(opts, :original_filename)
    content_type = detected_type || Keyword.get(opts, :content_type)
    type = Keyword.get(opts, :type)
    ext = extension_from_content_type(content_type) || Path.extname(source_path)

    original_dir = original_path_dir(owner_type, owner_id)
    File.mkdir_p!(original_dir)
    dest = Path.join(original_dir, "#{filename}#{ext}")

    case strip_exif_and_copy(source_path, dest) do
      :ok ->
        attrs = %{
          owner_type: owner_type,
          owner_id: owner_id,
          filename: filename,
          original_filename: original_filename,
          content_type: content_type,
          type: type
        }

        case Photos.create_photo(attrs) do
          {:ok, photo} ->
            PhotoProcessor.enqueue(photo)
            {:ok, photo}

          error ->
            File.rm(dest)
            error
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp strip_exif_and_copy(source_path, dest_path) do
    with {:ok, image} <- Image.open(source_path),
         {:ok, _} <- Image.write(image, dest_path, strip_metadata: true) do
      :ok
    else
      {:error, reason} -> {:error, {:exif_strip_failed, reason}}
    end
  end

  @doc """
  Validates that a file's magic bytes match a supported image format.
  Returns `{:ok, detected_type}` or `{:error, :invalid_image}`.
  """
  def validate_image_magic(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case detect_image_type(content) do
          nil -> {:error, :invalid_image}
          type -> {:ok, type}
        end

      {:error, _} ->
        {:error, :file_read_error}
    end
  end

  # PNG: 89 50 4E 47 0D 0A 1A 0A
  defp detect_image_type(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>),
    do: "image/png"

  # JPEG: FF D8 FF
  defp detect_image_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"

  # WebP: RIFF....WEBP
  defp detect_image_type(
         <<0x52, 0x49, 0x46, 0x46, _size::32, 0x57, 0x45, 0x42, 0x50, _::binary>>
       ),
       do: "image/webp"

  # HEIC/HEIF: ....ftyp followed by heic, heix, mif1, or msf1
  defp detect_image_type(<<_size::32, "ftyp", brand::binary-size(4), _::binary>>)
       when brand in ["heic", "heix", "mif1", "msf1", "hevc"],
       do: "image/heic"

  defp detect_image_type(_), do: nil

  @doc """
  Deletes all files associated with a photo (processed variants and original).
  """
  def delete_photo_files(%Photo{} = photo) do
    File.rm(processed_path(photo.id, :main))
    File.rm(processed_path(photo.id, :pixelated))
    File.rm(processed_path(photo.id, :thumbnail))

    case original_path(photo) do
      {:ok, path} -> File.rm(path)
      _ -> :ok
    end
  end

  @doc """
  Returns the directory for original uploads of a given owner.
  """
  def original_path_dir(owner_type, owner_id) do
    Path.join([Photos.upload_dir(), "originals", owner_type, owner_id])
  end

  @doc """
  Returns the directory for processed photos.
  """
  def processed_dir do
    Path.join(Photos.upload_dir(), "processed")
  end

  @doc """
  Returns the path to a processed photo variant.
  """
  def processed_path(photo_id, variant \\ :main) do
    filename =
      case variant do
        :main -> "#{photo_id}.webp"
        :pixelated -> "#{photo_id}_pixelated.webp"
        :thumbnail -> "#{photo_id}_thumb.webp"
      end

    Path.join(processed_dir(), filename)
  end

  @doc """
  Finds the original file for a photo (scanning for any extension).
  """
  def original_path(%Photo{} = photo) do
    dir = original_path_dir(photo.owner_type, photo.owner_id)
    pattern = Path.join(dir, "#{photo.filename}.*")

    case Path.wildcard(pattern) do
      [path | _] -> {:ok, path}
      [] -> {:error, :not_found}
    end
  end

  defp extension_from_content_type("image/jpeg"), do: ".jpg"
  defp extension_from_content_type("image/png"), do: ".png"
  defp extension_from_content_type("image/webp"), do: ".webp"
  defp extension_from_content_type("image/heic"), do: ".heic"
  defp extension_from_content_type(_), do: nil
end
