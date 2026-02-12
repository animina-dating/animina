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

  alias Animina.AI
  alias Animina.Photos
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
  their retry schedule and will be processed by the AI.Scheduler.

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
    Task.Supervisor.start_child(Animina.AI.TaskSupervisor, fn ->
      process_photo(photo_id)
    end)

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
    # Enqueue an AI job for classification instead of running inline.
    # The AI.Scheduler will pick it up and the Executor will handle
    # classification, side effects, and state transitions.
    owner_id = if photo.owner_type == "User", do: photo.owner_id, else: nil

    case AI.enqueue("photo_classification", %{"photo_id" => photo.id},
           subject_type: "Photo",
           subject_id: photo.id,
           requester_id: owner_id
         ) do
      {:ok, _job} ->
        Logger.info("Photo #{photo.id} enqueued for AI classification")
        # Return the photo as-is — it stays in ollama_checking until the AI job completes
        {:ok, photo}

      {:error, reason} ->
        Logger.error("Failed to enqueue AI classification for photo #{photo.id}: #{inspect(reason)}")
        Photos.queue_for_ollama_retry(photo)
        {:error, :enqueue_failed}
    end
  end

  @doc """
  Returns the Ollama prompt for photo analysis.

  The prompt requests detailed JSON with person detection, content safety,
  and attire assessment fields to enable specific user feedback.
  """
  def ollama_prompt do
    """
    You are an image classifier for a dating platform. Analyze the image and respond with ONLY valid JSON (no other text):

    {
      "photo_analysis": {
        "person_detection": {
          "contains_person": true/false,
          "person_count": number,
          "persons_facing_camera": number,
          "children_present": true/false,
          "adult_present": true/false
        },
        "content_safety": {
          "family_friendly": true/false,
          "nudity_detected": true/false,
          "explicit_content": true/false,
          "illegal_activity": true/false,
          "drug_use": true/false,
          "violence": true/false,
          "firearms_visible": true/false,
          "hunting_scene": true/false
        },
        "attire_assessment": {
          "appropriate_attire": true/false,
          "swimwear_detected": true/false,
          "underwear_detected": true/false,
          "shirtless": true/false,
          "outdoor_context": true/false,
          "beach_context": true/false
        },
        "animal_detection": {
          "is_an_animal": true/false,
          "is_a_dog": true/false,
          "is_a_cat": true/false
        },
        "sex_scene": true/false
      }
    }

    Rules:
    - family_friendly: false if content is not appropriate for all ages
    - nudity_detected: true if any nudity or exposed private parts
    - explicit_content: true if sexually explicit content
    - firearms_visible: true if any guns, rifles, or weapons visible
    - hunting_scene: true if hunting activity or dead animals shown
    - appropriate_attire: false if underwear visible or inappropriate for context
    - swimwear_detected: true if wearing swimsuit/bikini
    - beach_context: true if clearly at beach, pool, or similar outdoor water setting
    - is_an_animal: true if the main subject is an animal (not a human)
    - is_a_dog: true if a dog is the main subject of the photo
    - is_a_cat: true if a cat is the main subject of the photo
    """
  end

  @doc """
  Parses the Ollama response to extract classification results.

  Returns a structured map with nested person_detection, content_safety,
  and attire_assessment fields.
  """
  def parse_ollama_response(response) do
    case parse_json_response(response) do
      {:ok, parsed} ->
        normalize_parsed_response(parsed)

      {:error, _} ->
        # Fallback to legacy parsing for backwards compatibility
        parse_legacy_response(response)
    end
  end

  defp parse_json_response(response) do
    # Try to extract JSON from the response (model may include extra text)
    # Use a more robust regex that handles nested objects
    case Regex.run(~r/\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\}/s, response) do
      [json_str] -> Jason.decode(json_str)
      nil -> {:error, :no_json_found}
    end
  end

  defp normalize_parsed_response(parsed) do
    # Handle both new nested format and legacy flat format
    photo_analysis = Map.get(parsed, "photo_analysis", parsed)

    person = Map.get(photo_analysis, "person_detection", %{})
    content = Map.get(photo_analysis, "content_safety", %{})
    attire = Map.get(photo_analysis, "attire_assessment", %{})
    animal = Map.get(photo_analysis, "animal_detection", %{})

    %{
      person_detection: %{
        contains_person:
          get_bool(person, "contains_person", get_bool(parsed, "contains_person", false)),
        person_count: get_int(person, "person_count", 0),
        persons_facing_camera:
          get_int(
            person,
            "persons_facing_camera",
            get_int(parsed, "person_facing_camera_count", 0)
          ),
        children_present: get_bool(person, "children_present", false),
        adult_present: get_bool(person, "adult_present", true)
      },
      content_safety: %{
        family_friendly:
          get_bool(content, "family_friendly", get_bool(parsed, "family_friendly", true)),
        nudity_detected: get_bool(content, "nudity_detected", false),
        explicit_content: get_bool(content, "explicit_content", false),
        illegal_activity: get_bool(content, "illegal_activity", false),
        drug_use: get_bool(content, "drug_use", false),
        violence: get_bool(content, "violence", false),
        firearms_visible: get_bool(content, "firearms_visible", false),
        hunting_scene: get_bool(content, "hunting_scene", false)
      },
      attire_assessment: %{
        appropriate_attire: get_bool(attire, "appropriate_attire", true),
        swimwear_detected: get_bool(attire, "swimwear_detected", false),
        underwear_detected: get_bool(attire, "underwear_detected", false),
        shirtless: get_bool(attire, "shirtless", false),
        outdoor_context: get_bool(attire, "outdoor_context", false),
        beach_context: get_bool(attire, "beach_context", false)
      },
      animal_detection: %{
        is_an_animal: get_bool(animal, "is_an_animal", false),
        is_a_dog: get_bool(animal, "is_a_dog", false),
        is_a_cat: get_bool(animal, "is_a_cat", false)
      },
      sex_scene: get_bool(photo_analysis, "sex_scene", false)
    }
  end

  defp get_bool(map, key, default) when is_map(map) do
    case Map.get(map, key) do
      true -> true
      false -> false
      _ -> default
    end
  end

  defp get_int(map, key, default) when is_map(map) do
    case Map.get(map, key) do
      n when is_integer(n) -> n
      _ -> default
    end
  end

  # Legacy parsing for backwards compatibility with old response format
  defp parse_legacy_response(response) do
    upper = String.upcase(response)

    contains_person = parse_contains_person(upper)
    person_count = parse_person_count(upper)
    family_friendly = parse_family_friendly(upper)

    %{
      person_detection: %{
        contains_person: contains_person,
        person_count: if(contains_person, do: max(person_count, 1), else: 0),
        persons_facing_camera: person_count,
        children_present: false,
        adult_present: contains_person
      },
      content_safety: %{
        family_friendly: family_friendly,
        nudity_detected: not family_friendly,
        explicit_content: false,
        illegal_activity: false,
        drug_use: false,
        violence: false,
        firearms_visible: false,
        hunting_scene: false
      },
      attire_assessment: %{
        appropriate_attire: true,
        swimwear_detected: false,
        underwear_detected: false,
        shirtless: false,
        outdoor_context: false,
        beach_context: false
      },
      animal_detection: %{
        is_an_animal: false,
        is_a_dog: false,
        is_a_cat: false
      },
      sex_scene: false
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
         # Apply crop if available (mandatory for avatars, optional for moodboard)
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
  # - Moodboard photos: ONLY crop if user explicitly selected a crop region
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
    # Moodboard photos or other types: only crop if user explicitly chose to
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
