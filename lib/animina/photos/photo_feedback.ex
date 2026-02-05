defmodule Animina.Photos.PhotoFeedback do
  @moduledoc """
  Maps photo analysis violations to user-friendly error messages.

  Different rules apply to different photo types:
  - Avatar photos: All rules (face detection, content safety, attire)
  - Moodboard photos: Content safety rules only (no face requirements)
  """

  use Gettext, backend: AniminaWeb.Gettext

  @doc """
  Analyzes parsed Ollama response and returns violation info for avatar photos.

  Returns `{:ok, :approved}` if all checks pass, or `{:error, violation, message}`
  with the primary violation and user-friendly message.
  """
  def analyze_avatar(parsed) do
    with :ok <- check_content_safety(parsed),
         :ok <- check_attire(parsed),
         :ok <- check_avatar_attire_context(parsed),
         :ok <- check_face_detection(parsed) do
      {:ok, :approved}
    end
  end

  defp check_content_safety(parsed) do
    with :ok <- check_explicit_content(parsed) do
      check_prohibited_content(parsed.content_safety)
    end
  end

  defp check_explicit_content(parsed) do
    cs = parsed.content_safety

    cond do
      cs.nudity_detected ->
        {:error, :nudity, nudity_message()}

      not cs.family_friendly or cs.explicit_content ->
        {:error, :not_family_friendly, not_family_friendly_message()}

      parsed.sex_scene ->
        {:error, :sex_scene, sex_scene_message()}

      true ->
        :ok
    end
  end

  defp check_prohibited_content(cs) do
    cond do
      cs.firearms_visible ->
        {:error, :firearms, firearms_message()}

      cs.hunting_scene ->
        {:error, :hunting, hunting_message()}

      cs.illegal_activity or cs.drug_use or cs.violence ->
        {:error, :illegal_content, illegal_content_message()}

      true ->
        :ok
    end
  end

  defp check_attire(parsed) do
    attire = parsed.attire_assessment

    cond do
      not attire.appropriate_attire ->
        {:error, :inappropriate_attire, inappropriate_attire_message()}

      attire.underwear_detected ->
        {:error, :inappropriate_attire, inappropriate_attire_message()}

      true ->
        :ok
    end
  end

  defp check_avatar_attire_context(parsed) do
    attire = parsed.attire_assessment

    cond do
      attire.swimwear_detected and not attire.outdoor_context and not attire.beach_context ->
        {:error, :inappropriate_attire, swimwear_indoor_message()}

      attire.shirtless and not attire.beach_context and not attire.outdoor_context ->
        {:error, :inappropriate_attire, shirtless_indoor_message()}

      true ->
        :ok
    end
  end

  defp check_face_detection(parsed) do
    pd = parsed.person_detection

    cond do
      pd.children_present and not pd.adult_present -> {:error, :child_only, child_only_message()}
      not pd.contains_person -> {:error, :no_face, no_face_message()}
      pd.persons_facing_camera == 0 -> {:error, :no_face, no_face_message()}
      pd.persons_facing_camera > 1 -> {:error, :multiple_faces, multiple_faces_message()}
      true -> :ok
    end
  end

  @doc """
  Analyzes parsed Ollama response for moodboard photos.

  Moodboard photos only check content safety, not face requirements.
  Returns `{:ok, :approved}` if content is acceptable, or `{:error, violation, message}`.
  """
  def analyze_moodboard(parsed) do
    with :ok <- check_content_safety(parsed),
         :ok <- check_attire(parsed) do
      {:ok, :approved}
    end
  end

  @doc """
  Returns the error state to transition to based on the violation type.
  """
  def violation_to_state(:no_face), do: "no_face_error"
  def violation_to_state(:multiple_faces), do: "no_face_error"
  def violation_to_state(:child_only), do: "no_face_error"
  def violation_to_state(_), do: "error"

  @doc """
  Returns whether this violation should trigger automatic blacklisting.
  """
  def should_blacklist?(:nudity), do: true
  def should_blacklist?(:not_family_friendly), do: true
  def should_blacklist?(:sex_scene), do: true
  def should_blacklist?(:illegal_content), do: true
  def should_blacklist?(_), do: false

  # User-friendly error messages

  defp multiple_faces_message do
    dgettext(
      "errors",
      "Your profile photo should show only you. We detected multiple people facing the camera. Please upload a photo where you're the only one visible, or use a group photo for your moodboard instead."
    )
  end

  defp no_face_message do
    dgettext(
      "errors",
      "We couldn't detect a clear face in your photo. Please upload a photo where you're looking at the camera with your face clearly visible."
    )
  end

  defp child_only_message do
    dgettext(
      "errors",
      "Profile photos of children alone aren't allowed for safety reasons. If you'd like to include children in your photos, please ensure you (an adult) are also clearly visible in the photo."
    )
  end

  defp nudity_message do
    dgettext(
      "errors",
      "We detected nudity in this photo. Please upload a photo where you're appropriately dressed."
    )
  end

  defp not_family_friendly_message do
    dgettext(
      "errors",
      "This photo contains content that isn't appropriate for our platform. Please upload a family-friendly photo."
    )
  end

  defp firearms_message do
    dgettext(
      "errors",
      "Photos showing firearms aren't allowed on our platform. Please upload a different photo."
    )
  end

  defp hunting_message do
    dgettext(
      "errors",
      "Hunting photos aren't allowed on our platform. Please upload a different photo."
    )
  end

  defp sex_scene_message do
    dgettext(
      "errors",
      "This photo contains sexual content that isn't allowed on our platform. Please upload a different photo."
    )
  end

  defp illegal_content_message do
    dgettext(
      "errors",
      "This photo contains content depicting illegal activities, drugs, or violence. Please upload a different photo."
    )
  end

  defp inappropriate_attire_message do
    dgettext(
      "errors",
      "The attire in this photo doesn't meet our guidelines. Please upload a photo where you're appropriately dressed."
    )
  end

  defp swimwear_indoor_message do
    dgettext(
      "errors",
      "Swimwear is only appropriate for outdoor beach or pool settings. Please upload a different photo or one taken at the beach/pool."
    )
  end

  defp shirtless_indoor_message do
    dgettext(
      "errors",
      "Shirtless photos are only appropriate for outdoor beach or pool settings. Please upload a different photo or one taken at the beach/pool."
    )
  end
end
