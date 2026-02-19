defmodule Animina.AI.JobTypes.PhotoDescription do
  @moduledoc """
  AI job type for generating German-language photo descriptions.

  Uses a vision model to create accessibility-friendly descriptions
  of photos for use on the dating platform.
  """

  @behaviour Animina.AI.JobType

  alias Animina.ActivityLog
  alias Animina.Photos

  @description_prompt """
  Beschreibe dieses Foto sachlich in maximal 500 Zeichen auf Deutsch.
  Kontext: Online-Dating-Plattform. Die Beschreibung ist für Personen, die das Foto nicht sehen können.
  Beschreibe kurz und knapp: wer ist zu sehen, was tut die Person, wo wurde das Foto aufgenommen.
  Keine blumige oder romantische Sprache. Sei neutral und präzise.
  Antworte NUR mit der Beschreibung, ohne Anführungszeichen oder Erklärungen.
  """

  @impl true
  def job_type, do: "photo_description"

  @impl true
  def model_family, do: :vision

  @impl true
  def default_model, do: "qwen3-vl:8b"

  @impl true
  def default_priority, do: 4

  @impl true
  def max_attempts, do: 3

  @impl true
  def allowed_model_downgrades, do: []

  @impl true
  def build_prompt(_params) do
    @description_prompt
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
      photo -> save_description(job, photo, raw_response)
    end
  end

  defp save_description(job, photo, raw_response) do
    description = raw_response |> String.trim() |> String.slice(0, 500)

    case Photos.update_photo_description(photo, %{
           description: description,
           description_generated_at: DateTime.utc_now(:second),
           description_model: job.model || default_model()
         }) do
      {:ok, _updated} ->
        owner_id = if photo.owner_type == "User", do: photo.owner_id, else: nil

        ActivityLog.log(
          "system",
          "photo_description_generated",
          "Generated German description for photo #{photo.id}",
          subject_id: owner_id,
          metadata: %{
            "model" => job.model || default_model(),
            "description_length" => String.length(description)
          }
        )

        {:ok, %{"description_length" => String.length(description)}}

      {:error, changeset} ->
        {:error, {:save_failed, inspect(changeset.errors)}}
    end
  end
end
