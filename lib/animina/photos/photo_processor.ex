defmodule Animina.Photos.PhotoProcessor do
  @moduledoc """
  GenServer for asynchronous photo processing.

  Pipeline: resize → convert to WebP → strip EXIF → blacklist check → Ollama check → approve/reject.

  Ollama checks for:
  - family_friendly: must be true
  - contains_person: must be true
  - person_facing_camera_count: must be exactly 1

  All processing steps are logged to the audit log for complete traceability.
  """

  use GenServer
  require Logger

  alias Animina.Accounts
  alias Animina.FeatureFlags
  alias Animina.Photos
  alias Animina.Photos.OllamaClient
  alias Animina.Photos.Photo

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enqueues a photo for background processing.
  """
  def enqueue(%Photo{} = photo) do
    GenServer.cast(__MODULE__, {:process, photo.id})
  end

  # States that should be recovered after restart (intermediate processing states)
  # Note: pending_ollama state is NOT included as it has its own retry schedule
  @stuck_states ~w(processing ollama_checking)

  @doc """
  Recovers photos stuck in intermediate processing states after a server restart.

  This function finds all photos in intermediate states (processing, ollama_checking)
  and transitions them back to `pending` state so they can be re-processed.

  Note: Photos in `pending_ollama` states are NOT recovered here. They maintain
  their retry schedule and will be processed by the OllamaRetryScheduler.

  Returns `{:ok, count}` with the number of recovered photos.
  """
  def recover_stuck_photos do
    stuck_photos = Photos.list_photos_by_states(@stuck_states)
    count = length(stuck_photos)

    if count > 0 do
      Logger.info("Recovering #{count} stuck photos after restart")
    end

    Enum.each(stuck_photos, fn photo ->
      recover_photo(photo)
    end)

    {:ok, count}
  end

  defp recover_photo(%Photo{} = photo) do
    previous_state = photo.state

    Photos.log_event(photo, "recovery_after_restart", "system", nil, %{
      previous_state: previous_state
    })

    case Photos.transition_photo(photo, "pending") do
      {:ok, updated_photo} ->
        Logger.info("Recovered stuck photo #{photo.id} from #{previous_state} -> pending")
        enqueue(updated_photo)

      {:error, reason} ->
        Logger.error("Failed to recover photo #{photo.id}: #{inspect(reason)}")
    end
  end

  # --- Server callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process, photo_id}, state) do
    Task.start(fn -> process_photo(photo_id) end)
    {:noreply, state}
  end

  # --- Processing pipeline ---

  defp process_photo(photo_id) do
    photo = Photos.get_photo(photo_id)

    if is_nil(photo) do
      Logger.warning("PhotoProcessor: Photo #{photo_id} not found, skipping processing")
      :ok
    else
      do_process_photo(photo)
    end
  end

  defp do_process_photo(photo) do

    # Log photo uploaded event
    Photos.log_event(photo, "photo_uploaded", "user", photo.owner_id, %{
      filename: photo.original_filename,
      content_type: photo.content_type
    })

    with {:ok, photo} <- transition_to_processing(photo),
         {:ok, photo} <- process_image(photo),
         {:ok, photo} <- check_blacklist(photo),
         {:ok, photo} <- run_ollama_check(photo) do
      # Log final approval
      Photos.log_event(photo, "photo_approved", "system", nil, %{via: "automated_processing"})

      # Delete original file after successful processing to save disk space
      # and ensure no unprocessed EXIF data remains
      cleanup_original_file(photo)

      broadcast_approved(photo)

      Logger.info("Photo #{photo.id} processed and approved")
    else
      {:error, :blacklisted} ->
        Logger.info("Photo #{photo.id} rejected: matches blacklist")

      {:error, :no_face_detected} ->
        Logger.info("Photo #{photo.id} rejected: no face detected or not facing camera")

      {:error, :not_family_friendly} ->
        Logger.info("Photo #{photo.id} rejected: not family friendly")

      {:error, reason} ->
        Logger.error("Photo #{photo.id} processing failed: #{inspect(reason)}")
    end
  end

  # --- Ollama Check ---
  # Uses a simple prompt to check family_friendly, contains_person, and person_facing_camera_count

  defp run_ollama_check(photo) do
    # Photo is already in ollama_checking state (transitioned by process_image)
    # Apply configured delay for UX testing
    FeatureFlags.apply_delay(:photo_ollama_check)
    run_ollama_classification(photo)
  end

  defp run_ollama_classification(photo) do
    ollama_model = Photos.ollama_model()
    thumbnail_path = Photos.processed_path(photo, :thumbnail)

    image_data = File.read!(thumbnail_path) |> Base.encode64()

    prompt = """
    You are an image classifier. Given the image, respond with JSON: { "contains_person": true/false, "person_facing_camera_count": number, "family_friendly": true/false } Check if the image shows exactly one person and if the content is appropriate for all ages.
    """

    # Look up user info for debug logging
    {user_email, user_display_name} = get_owner_info(photo)

    {duration_us, result} =
      :timer.tc(fn ->
        OllamaClient.completion(
          model: ollama_model,
          prompt: prompt,
          images: [image_data],
          photo_id: photo.id,
          user_email: user_email,
          user_display_name: user_display_name
        )
      end)

    duration_ms = div(duration_us, 1000)

    case result do
      {:ok, %{"response" => response}, server_url} ->
        # Log Ollama response in development
        if Application.get_env(:animina, :env) == :dev do
          Logger.info("Ollama response for photo #{photo.id}: #{response}")
        end

        parsed = parse_ollama_response(response)

        Photos.log_event(
          photo,
          "ollama_checked",
          "ai",
          nil,
          %{
            model: ollama_model,
            contains_person: parsed.contains_person,
            person_facing_camera_count: parsed.person_facing_camera_count,
            family_friendly: parsed.family_friendly,
            raw_response: response
          },
          duration_ms: duration_ms,
          ollama_server_url: server_url
        )

        finalize_ollama_result(photo, parsed)

      {:error, reason} ->
        Logger.warning("Ollama check failed for photo #{photo.id}: #{inspect(reason)}")

        Photos.log_event(
          photo,
          "ollama_checked",
          "ai",
          nil,
          %{
            model: ollama_model,
            result: "queued_for_retry",
            error: inspect(reason)
          },
          duration_ms: duration_ms
        )

        # Queue for retry
        Photos.queue_for_ollama_retry(photo)
    end
  end

  @doc """
  Parses the Ollama response to extract classification results.

  Expected JSON format:
  ```json
  {
    "contains_person": true/false,
    "person_facing_camera_count": number,
    "family_friendly": true/false
  }
  ```

  Returns a map with the parsed values.
  """
  def parse_ollama_response(response) do
    case parse_json_response(response) do
      {:ok, parsed} ->
        %{
          contains_person: Map.get(parsed, "contains_person", false),
          person_facing_camera_count: Map.get(parsed, "person_facing_camera_count", 0),
          family_friendly: Map.get(parsed, "family_friendly", true)
        }

      {:error, _} ->
        # Fallback to text parsing for robustness
        parse_text_response(response)
    end
  end

  defp parse_json_response(response) do
    # Try to extract JSON from the response (model may include extra text)
    case Regex.run(~r/\{[^}]+\}/s, response) do
      [json_str] -> Jason.decode(json_str)
      nil -> {:error, :no_json_found}
    end
  end

  defp parse_text_response(response) do
    upper = String.upcase(response)

    %{
      contains_person: parse_contains_person(upper),
      person_facing_camera_count: parse_person_count(upper),
      family_friendly: parse_family_friendly(upper)
    }
  end

  defp parse_contains_person(upper) do
    cond do
      String.contains?(upper, "CONTAINS_PERSON\": TRUE") -> true
      String.contains?(upper, "\"CONTAINS_PERSON\":TRUE") -> true
      String.contains?(upper, "CONTAINS_PERSON: TRUE") -> true
      String.contains?(upper, "CONTAINS_PERSON\":TRUE") -> true
      true -> false
    end
  end

  defp parse_person_count(upper) do
    case Regex.run(~r/PERSON_FACING_CAMERA_COUNT["\s:]+(\d+)/i, upper) do
      [_, count] -> String.to_integer(count)
      nil -> 0
    end
  end

  defp parse_family_friendly(upper) do
    cond do
      String.contains?(upper, "FAMILY_FRIENDLY\": FALSE") -> false
      String.contains?(upper, "\"FAMILY_FRIENDLY\":FALSE") -> false
      String.contains?(upper, "FAMILY_FRIENDLY: FALSE") -> false
      String.contains?(upper, "FAMILY_FRIENDLY\":FALSE") -> false
      true -> true
    end
  end

  defp finalize_ollama_result(photo, parsed) do
    cond do
      not parsed.family_friendly ->
        # Not family friendly - reject
        maybe_auto_blacklist(photo)

        Photos.log_event(photo, "photo_rejected", "system", nil, %{
          reason: "not_family_friendly",
          state: "error"
        })

        Photos.transition_photo(photo, "error", %{
          error_message: "Content is not family friendly"
        })

        {:error, :not_family_friendly}

      gallery_photo?(photo) ->
        # Gallery photos skip face detection - any content is allowed
        # (as long as it's family friendly, checked above)
        Photos.transition_photo(photo, "approved")

      not parsed.contains_person or parsed.person_facing_camera_count != 1 ->
        # No person or not exactly one person facing camera - reject
        Photos.log_event(photo, "photo_rejected", "system", nil, %{
          reason: "no_face_detected",
          contains_person: parsed.contains_person,
          person_facing_camera_count: parsed.person_facing_camera_count,
          state: "no_face_error"
        })

        Photos.transition_photo(photo, "no_face_error", %{
          error_message: "Photo must show exactly one person facing the camera"
        })

        {:error, :no_face_detected}

      true ->
        # All checks passed - approve
        Photos.transition_photo(photo, "approved")
    end
  end

  # Gallery photos have owner_type "GalleryItem" and skip face detection
  defp gallery_photo?(%Photo{owner_type: "GalleryItem"}), do: true
  defp gallery_photo?(_), do: false

  defp transition_to_processing(photo) do
    Photos.log_event(photo, "processing_started", "system", nil, %{})
    Photos.transition_photo(photo, "processing")
  end

  defp process_image(photo) do
    case Photos.original_path(photo) do
      {:ok, original_path} ->
        do_process_image(photo, original_path)

      {:error, _} ->
        Photos.transition_photo(photo, "error", %{error_message: "Original file not found"})
        {:error, :original_not_found}
    end
  end

  defp do_process_image(photo, original_path) do
    max_dim = Photos.max_dimension()
    thumb_dim = Photos.thumbnail_dimension()
    quality = Photos.webp_quality()

    # Create owner-specific directory for processed photos
    processed_dir = Photos.processed_path_dir(photo.owner_type, photo.owner_id)
    File.mkdir_p!(processed_dir)

    main_path = Photos.processed_path(photo, :main)
    thumbnail_path = Photos.processed_path(photo, :thumbnail)

    with {:ok, image} <- Image.open(original_path),
         # Apply crop if available (mandatory for avatars, optional for gallery)
         {:ok, image} <- maybe_apply_crop(image, photo),
         {:ok, image} <- resize_to_max(image, max_dim),
         {:ok, _} <- Image.write(image, main_path, quality: quality, strip_metadata: true),
         {width, height} <- {Image.width(image), Image.height(image)},
         # Create thumbnail for AI analysis and UX
         {:ok, thumb} <- resize_to_max(image, thumb_dim),
         {:ok, _} <- Image.write(thumb, thumbnail_path, quality: quality, strip_metadata: true),
         # Compute dhash for blacklist checking
         {:ok, dhash} <- Photos.compute_dhash(main_path),
         # Clean up crop data file after successful processing
         _ <- Photos.delete_crop_data(photo) do
      Photos.log_event(photo, "processing_completed", "system", nil, %{
        width: width,
        height: height
      })

      result =
        Photos.transition_photo(photo, "ollama_checking", %{
          width: width,
          height: height,
          dhash: dhash
        })

      # Broadcast state change so UI can show "Analyzing..." overlay
      case result do
        {:ok, updated_photo} -> broadcast_state_changed(updated_photo)
        _ -> :ok
      end

      result
    else
      {:error, reason} ->
        error_msg = "Image processing failed: #{inspect(reason)}"

        Photos.log_event(photo, "photo_rejected", "system", nil, %{
          reason: error_msg,
          state: "error"
        })

        Photos.transition_photo(photo, "error", %{error_message: error_msg})
        {:error, reason}
    end
  end

  # Apply crop based on photo type:
  # - Avatar photos: ALWAYS crop to square (mandatory, use center crop if no data)
  # - Gallery photos: ONLY crop if user explicitly selected a crop region
  defp maybe_apply_crop(image, %Photo{type: "avatar"} = photo) do
    case Photos.get_crop_data(photo) do
      nil ->
        # Avatar with no crop data: apply center square crop as fallback
        apply_center_crop(image)

      crop_data ->
        # Avatar with crop data: apply user's selection
        apply_crop(image, crop_data)
    end
  end

  defp maybe_apply_crop(image, photo) do
    # Gallery photos or other types: only crop if user explicitly chose to
    case Photos.get_crop_data(photo) do
      nil ->
        # No crop data: keep original dimensions
        {:ok, image}

      crop_data ->
        # User chose to crop: apply their selection
        apply_crop(image, crop_data)
    end
  end

  # Apply crop using coordinates from user selection
  defp apply_crop(image, %{x: x, y: y, width: width, height: height}) do
    Image.crop(image, x, y, width, height)
  end

  # Center square crop for avatars without explicit crop data
  @doc """
  Applies a center square crop to an image.
  Used as fallback for avatar photos when no crop data is provided.
  """
  def apply_center_crop(image) do
    img_width = Image.width(image)
    img_height = Image.height(image)
    size = min(img_width, img_height)
    x = div(img_width - size, 2)
    y = div(img_height - size, 2)
    Image.crop(image, x, y, size, size)
  end

  # --- Blacklist check ---

  defp check_blacklist(%Photo{dhash: nil} = photo) do
    # No dhash computed, skip blacklist check
    Photos.log_event(photo, "blacklist_checked", "ai", nil, %{
      result: "skipped",
      reason: "no_dhash"
    })

    {:ok, photo}
  end

  defp check_blacklist(%Photo{dhash: dhash} = photo) do
    {duration_us, result} = :timer.tc(fn -> Photos.check_blacklist(dhash) end)
    duration_ms = div(duration_us, 1000)

    case result do
      nil ->
        Photos.log_event(photo, "blacklist_checked", "ai", nil, %{result: "no_match"},
          duration_ms: duration_ms
        )

        {:ok, photo}

      entry ->
        distance = Photos.hamming_distance(entry.dhash, dhash)

        Photos.log_event(
          photo,
          "blacklist_matched",
          "ai",
          nil,
          %{
            entry_id: entry.id,
            distance: distance,
            reason: entry.reason
          },
          duration_ms: duration_ms
        )

        Photos.log_event(photo, "photo_rejected", "system", nil, %{
          reason: "blacklisted",
          state: "error"
        })

        Photos.transition_photo(photo, "error", %{
          error_message: "Photo matches blacklisted content"
        })

        {:error, :blacklisted}
    end
  end

  defp maybe_auto_blacklist(%Photo{dhash: nil}), do: :ok

  defp maybe_auto_blacklist(%Photo{dhash: dhash} = photo) do
    # Check if already blacklisted
    case Photos.get_blacklist_entry_by_dhash(dhash) do
      nil ->
        # Add to blacklist automatically
        case Photos.add_to_blacklist(dhash, "Auto-blacklisted: not family friendly", nil, photo) do
          {:ok, _entry} ->
            Photos.log_event(photo, "blacklist_added", "ai", nil, %{
              reason: "auto_not_family_friendly"
            })

          {:error, _} ->
            :ok
        end

      _entry ->
        # Already blacklisted
        :ok
    end
  end

  defp resize_to_max(image, max_dim) do
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

  # Look up owner info for debug logging
  # Only returns user info for User-owned photos
  defp get_owner_info(%Photo{owner_type: "User", owner_id: owner_id}) when not is_nil(owner_id) do
    case Accounts.get_user(owner_id) do
      nil -> {nil, nil}
      user -> {user.email, user.display_name}
    end
  end

  defp get_owner_info(_photo), do: {nil, nil}

  defp broadcast_approved(%Photo{} = photo) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      "photos:#{photo.owner_type}:#{photo.owner_id}",
      {:photo_approved, photo}
    )
  end

  defp broadcast_state_changed(%Photo{} = photo) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      "photos:#{photo.owner_type}:#{photo.owner_id}",
      {:photo_state_changed, photo}
    )
  end

  # Delete original file after successful processing to save disk space
  # and prevent any unprocessed EXIF data from remaining on disk
  defp cleanup_original_file(%Photo{} = photo) do
    case Photos.original_path(photo) do
      {:ok, path} ->
        case File.rm(path) do
          :ok ->
            Logger.debug("Cleaned up original file for photo #{photo.id}")
            :ok

          {:error, reason} ->
            Logger.warning(
              "Failed to clean up original file for photo #{photo.id}: #{inspect(reason)}"
            )

            :ok
        end

      {:error, :not_found} ->
        # Already deleted or never existed
        :ok
    end
  end
end
