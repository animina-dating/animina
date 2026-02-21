defmodule Animina.AI.JobTypes.PhotoClassification do
  @moduledoc """
  AI job type for photo classification (content safety, face detection, etc.).

  Uses a vision model to analyze photos and determine if they are appropriate
  for the dating platform. Handles both avatar and moodboard photos.
  """

  @behaviour Animina.AI.JobType

  alias Animina.Photos
  alias Animina.Photos.PhotoFeedback
  alias Animina.Photos.PhotoProcessor

  @impl true
  def job_type, do: "photo_classification"

  @impl true
  def model_family, do: :vision

  @impl true
  def default_model, do: "qwen3-vl:8b"

  @impl true
  def default_priority, do: 3

  @impl true
  def max_attempts, do: 20

  @impl true
  def allowed_model_downgrades, do: ["qwen3-vl:4b", "qwen3-vl:2b"]

  @impl true
  def build_prompt(_params) do
    PhotoProcessor.ollama_prompt()
  end

  @impl true
  def prepare_input(%{"photo_id" => photo_id}) do
    photo = Photos.get_photo(photo_id)

    if is_nil(photo) do
      {:error, :photo_not_found}
    else
      thumbnail_path = Photos.processed_path(photo, :thumbnail)

      case File.read(thumbnail_path) do
        {:ok, image_bytes} ->
          {:ok, [images: [Base.encode64(image_bytes)]]}

        {:error, reason} ->
          {:error, {:thumbnail_read_failed, reason}}
      end
    end
  end

  def prepare_input(_), do: {:error, :missing_photo_id}

  @impl true
  def handle_result(job, raw_response) do
    case Photos.get_photo(job.params["photo_id"]) do
      nil -> {:error, :photo_not_found}
      photo -> classify_photo(job, photo, raw_response)
    end
  end

  defp classify_photo(job, photo, raw_response) do
    parsed = PhotoProcessor.parse_ollama_response(raw_response)

    Photos.log_event(
      photo,
      "ollama_checked",
      "ai",
      nil,
      %{
        model: job.model,
        person_detection: parsed.person_detection,
        content_safety: parsed.content_safety,
        attire_assessment: parsed.attire_assessment,
        animal_detection: parsed.animal_detection,
        sex_scene: parsed.sex_scene,
        via: "ai_job_service"
      },
      duration_ms: job.duration_ms
    )

    analysis_result =
      if moodboard_photo?(photo) do
        PhotoFeedback.analyze_moodboard(parsed)
      else
        PhotoFeedback.analyze_avatar(parsed)
      end

    result_map = %{
      "person_detection" => stringify_keys(parsed.person_detection),
      "content_safety" => stringify_keys(parsed.content_safety),
      "attire_assessment" => stringify_keys(parsed.attire_assessment),
      "animal_detection" => stringify_keys(parsed.animal_detection),
      "sex_scene" => parsed.sex_scene
    }

    apply_classification(analysis_result, photo, parsed, result_map)
  end

  defp apply_classification({:ok, :approved}, photo, _parsed, result_map) do
    case Photos.transition_photo(photo, "approved", %{
           ollama_retry_count: 0,
           ollama_retry_at: nil,
           ollama_check_type: nil
         }) do
      {:ok, _photo} ->
        {:ok, Map.put(result_map, "verdict", "approved")}

      {:error, reason} ->
        {:error, {:transition_failed, reason}}
    end
  end

  defp apply_classification({:error, violation, message}, photo, parsed, result_map) do
    new_state = PhotoFeedback.violation_to_state(violation)

    if PhotoFeedback.should_blacklist?(violation) do
      maybe_auto_blacklist(photo)
    end

    Photos.log_event(photo, "photo_rejected", "system", nil, %{
      reason: Atom.to_string(violation),
      state: new_state,
      person_detection: parsed.person_detection,
      content_safety: parsed.content_safety
    })

    case Photos.transition_photo(photo, new_state, %{
           error_message: message,
           ollama_retry_count: 0,
           ollama_retry_at: nil,
           ollama_check_type: nil
         }) do
      {:ok, _photo} ->
        {:ok,
         Map.merge(result_map, %{"verdict" => "rejected", "reason" => Atom.to_string(violation)})}

      {:error, reason} ->
        {:error, {:transition_failed, reason}}
    end
  end

  # --- Private ---

  defp moodboard_photo?(%{owner_type: "MoodboardItem"}), do: true
  defp moodboard_photo?(_), do: false

  defp maybe_auto_blacklist(%{dhash: nil}), do: :ok

  defp maybe_auto_blacklist(%{dhash: dhash} = photo) do
    case Photos.get_blacklist_entry_by_dhash(dhash) do
      nil ->
        case Photos.add_to_blacklist(dhash, "Auto-blacklisted: not family friendly", nil, photo) do
          {:ok, _entry} ->
            Photos.log_event(photo, "blacklist_added", "ai", nil, %{
              reason: "auto_not_family_friendly"
            })

          {:error, _} ->
            :ok
        end

      _entry ->
        :ok
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
