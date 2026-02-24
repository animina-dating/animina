defmodule Animina.Photos.FileManagement do
  @moduledoc """
  File management utilities for photo uploads and processing.

  Handles file validation, storage paths, and EXIF stripping.
  """

  require Logger

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
    crop_data = Keyword.get(opts, :crop_data)
    ext = extension_from_content_type(content_type) || Path.extname(source_path)

    original_dir = original_path_dir(owner_type, owner_id)
    File.mkdir_p!(original_dir)
    dest = Path.join(original_dir, "#{filename}#{ext}")

    case strip_exif_and_copy(source_path, dest) do
      :ok ->
        # Store crop data as sidecar JSON if provided
        if crop_data do
          crop_path = Path.join(original_dir, "#{filename}.crop.json")
          File.write!(crop_path, Jason.encode!(crop_data))
        end

        attrs = %{
          owner_type: owner_type,
          owner_id: owner_id,
          filename: filename,
          original_filename: original_filename,
          content_type: content_type,
          type: type
        }

        create_photo_record(attrs, dest, original_dir, filename, opts)

      {:error, _reason} = error ->
        error
    end
  end

  defp create_photo_record(attrs, dest, original_dir, filename, opts) do
    case Photos.create_photo(attrs) do
      {:ok, photo} ->
        maybe_enqueue_photo(photo, opts)
        {:ok, photo}

      error ->
        File.rm(dest)
        crop_path = Path.join(original_dir, "#{filename}.crop.json")
        File.rm(crop_path)
        error
    end
  end

  defp maybe_enqueue_photo(photo, opts) do
    unless Keyword.get(opts, :skip_enqueue, false) do
      PhotoProcessor.enqueue(photo)
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
  Resizes an image so its longest dimension does not exceed `max_dim`.
  Returns `{:ok, resized_image}` or passes through `{:ok, image}` if already small enough.
  """
  def resize_to_max(image, max_dim) do
    width = Image.width(image)
    height = Image.height(image)
    longest = max(width, height)

    if longest > max_dim do
      scale = max_dim / longest
      Image.resize(image, scale)
    else
      {:ok, image}
    end
  end

  @doc """
  Validates that a file's magic bytes match a supported image format.
  Returns `{:ok, detected_type}` or `{:error, :invalid_image}`.
  """
  def validate_image_magic(file_path) do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        header = IO.binread(file, 12)
        File.close(file)

        case detect_image_type(header) do
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
    for variant <- [:main, :thumbnail, :pixel, :review_pixel] do
      path = processed_path(photo, variant)
      rm_file(path, "variant")
    end

    case original_path(photo) do
      {:ok, path} -> rm_file(path, "original")
      _ -> :ok
    end
  end

  defp rm_file(path, label) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> Logger.warning("[Photos] Failed to delete #{label} #{path}: #{reason}")
    end
  end

  @doc """
  Generates a heavily pixelated variant of the main processed photo.

  Used for sneak-peek teasers. Idempotent — skips if the pixel file
  already exists. Returns `:ok` or `{:error, reason}`.
  """
  def generate_pixel_variant(%Photo{} = photo) do
    pixel_path = processed_path(photo, :pixel)

    if File.exists?(pixel_path) do
      :ok
    else
      main_path = processed_path(photo, :main)

      with true <- File.exists?(main_path),
           {:ok, image} <- Image.open(main_path),
           {:ok, pixelated} <- Image.pixelate(image, 0.035),
           :ok <- File.mkdir_p(Path.dirname(pixel_path)),
           {:ok, _} <- Image.write(pixelated, pixel_path, quality: 60) do
        :ok
      else
        false -> {:error, :main_not_found}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Generates a very heavily pixelated variant for the "In review" placeholder.

  Uses 0.01 pixelation (much bigger blocks than the spotlight `:pixel` variant)
  so the image is completely unrecognizable but shows color tones.
  Idempotent — skips if the file already exists.
  """
  def generate_review_pixel_variant(%Photo{} = photo) do
    review_pixel_path = processed_path(photo, :review_pixel)

    if File.exists?(review_pixel_path) do
      :ok
    else
      main_path = processed_path(photo, :main)

      with true <- File.exists?(main_path),
           {:ok, image} <- Image.open(main_path),
           {:ok, pixelated} <- Image.pixelate(image, 0.025),
           :ok <- File.mkdir_p(Path.dirname(review_pixel_path)),
           {:ok, _} <- Image.write(pixelated, review_pixel_path, quality: 60) do
        :ok
      else
        false -> {:error, :main_not_found}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Generates the review pixel variant from an already-loaded Vix.Vips.Image.

  Called during the processing pipeline to avoid re-reading the main file.
  """
  def generate_review_pixel_from_image(%Photo{} = photo, image) do
    review_pixel_path = processed_path(photo, :review_pixel)

    with {:ok, pixelated} <- Image.pixelate(image, 0.025),
         :ok <- File.mkdir_p(Path.dirname(review_pixel_path)),
         {:ok, _} <- Image.write(pixelated, review_pixel_path, quality: 60) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the directory for original uploads of a given owner.
  """
  def original_path_dir(owner_type, owner_id) do
    Path.join([Photos.upload_dir(), "originals", owner_type, owner_id])
  end

  @doc """
  Returns the base directory for processed photos.
  """
  def processed_dir do
    Path.join(Photos.upload_dir(), "processed")
  end

  @doc """
  Returns the directory for processed photos of a given owner.
  """
  def processed_path_dir(owner_type, owner_id) do
    Path.join([processed_dir(), owner_type, owner_id])
  end

  @doc """
  Returns the path to a processed photo variant.

  Accepts either a Photo struct (preferred) or a photo_id with owner info.
  When given a Photo struct, uses owner_type and owner_id to build the path.
  """
  def processed_path(%Photo{} = photo, variant \\ :main) do
    dir = processed_path_dir(photo.owner_type, photo.owner_id)
    filename = processed_filename(photo.id, variant)
    Path.join(dir, filename)
  end

  def processed_path(photo_id, owner_type, owner_id, variant) when is_binary(photo_id) do
    dir = processed_path_dir(owner_type, owner_id)
    filename = processed_filename(photo_id, variant)
    Path.join(dir, filename)
  end

  defp processed_filename(photo_id, variant) do
    case variant do
      :main -> "#{photo_id}.webp"
      :thumbnail -> "#{photo_id}_thumb.webp"
      :pixel -> "#{photo_id}_pixel.webp"
      :review_pixel -> "#{photo_id}_review_pixel.webp"
    end
  end

  @doc """
  Finds the original file for a photo (scanning for any extension).
  """
  def original_path(%Photo{} = photo) do
    dir = original_path_dir(photo.owner_type, photo.owner_id)
    pattern = Path.join(dir, "#{photo.filename}.*")

    case Path.wildcard(pattern) do
      paths ->
        # Filter out .crop.json files
        image_paths = Enum.reject(paths, &String.ends_with?(&1, ".crop.json"))

        case image_paths do
          [path | _] -> {:ok, path}
          [] -> {:error, :not_found}
        end
    end
  end

  @doc """
  Reads crop data from the sidecar JSON file if it exists.
  Returns the crop data map or nil if no crop data exists.
  """
  def get_crop_data(%Photo{} = photo) do
    dir = original_path_dir(photo.owner_type, photo.owner_id)
    crop_path = Path.join(dir, "#{photo.filename}.crop.json")

    case File.read(crop_path) do
      {:ok, json} ->
        case Jason.decode(json, keys: :atoms!) do
          {:ok, data} -> data
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Deletes the crop data sidecar file if it exists.
  """
  def delete_crop_data(%Photo{} = photo) do
    dir = original_path_dir(photo.owner_type, photo.owner_id)
    crop_path = Path.join(dir, "#{photo.filename}.crop.json")
    File.rm(crop_path)
  end

  defp extension_from_content_type("image/jpeg"), do: ".jpg"
  defp extension_from_content_type("image/png"), do: ".png"
  defp extension_from_content_type("image/webp"), do: ".webp"
  defp extension_from_content_type("image/heic"), do: ".heic"
  defp extension_from_content_type(_), do: nil
end
