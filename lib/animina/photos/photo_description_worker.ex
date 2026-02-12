defmodule Animina.Photos.PhotoDescriptionWorker do
  @moduledoc """
  GenServer that generates German-language descriptions for approved photos
  using the Ollama vision model.

  Runs as a low-priority background job — only when Ollama is idle (no photo
  classification or retry work pending). Polls every 60 seconds.
  """

  use GenServer
  require Logger

  alias Animina.ActivityLog
  alias Animina.Photos
  alias Animina.Photos.OllamaClient
  alias Animina.Photos.OllamaSemaphore

  @poll_interval_ms 60_000
  @description_model "qwen3-vl:8b"

  @description_prompt """
  Beschreibe dieses Foto in maximal 2028 Zeichen auf Deutsch.
  Der Kontext ist eine Online-Dating-Plattform.
  Die Beschreibung soll das Foto so beschreiben, dass eine Person, die das Foto nicht sehen kann,
  sich ein gutes Bild davon machen kann. Beschreibe was du siehst: die Person(en),
  die Umgebung, die Stimmung, die Aktivität. Sei freundlich und positiv.
  Antworte NUR mit der Beschreibung, ohne Anführungszeichen oder Erklärungen.
  """

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the current worker statistics.
  """
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)

    state = %{
      poll_interval: poll_interval,
      total_processed: 0,
      total_succeeded: 0,
      total_failed: 0
    }

    # Schedule first poll after 10s startup delay
    Process.send_after(self(), :poll, 10_000)

    Logger.info("PhotoDescriptionWorker started with poll_interval=#{poll_interval}ms")

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state = do_poll(state)
    Process.send_after(self(), :poll, state.poll_interval)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    pending = Photos.count_photos_needing_description()

    stats = %{
      pending: pending,
      total_processed: state.total_processed,
      total_succeeded: state.total_succeeded,
      total_failed: state.total_failed
    }

    {:reply, stats, state}
  end

  # --- Private Functions ---

  defp do_poll(state) do
    if ollama_idle?() do
      photos = Photos.list_photos_needing_description(3)

      Enum.reduce_while(photos, state, &process_if_idle/2)
    else
      state
    end
  end

  defp process_if_idle(photo, acc) do
    if ollama_idle?() do
      {:cont, generate_description(photo, acc)}
    else
      Logger.debug("PhotoDescriptionWorker: Ollama no longer idle, yielding")
      {:halt, acc}
    end
  end

  defp ollama_idle? do
    semaphore_status = OllamaSemaphore.status()
    semaphore_idle = semaphore_status.active == 0 and semaphore_status.waiting == 0
    queue_empty = Photos.count_ollama_queue() == 0
    no_retries_due = Photos.list_photos_due_for_ollama_retry(1) == []

    semaphore_idle and queue_empty and no_retries_due
  end

  defp generate_description(photo, state) do
    case OllamaSemaphore.acquire(5_000) do
      :ok ->
        try do
          do_generate_description(photo, state)
        after
          OllamaSemaphore.release()
        end

      {:error, :timeout} ->
        Logger.debug("PhotoDescriptionWorker: Semaphore busy, skipping")
        state
    end
  end

  defp do_generate_description(photo, state) do
    thumbnail_path = Photos.processed_path(photo, :thumbnail)

    case File.read(thumbnail_path) do
      {:ok, image_bytes} ->
        image_data = Base.encode64(image_bytes)
        owner_id = if photo.owner_type == "User", do: photo.owner_id, else: nil

        result =
          OllamaClient.completion(
            model: @description_model,
            prompt: @description_prompt,
            images: [image_data],
            photo_id: photo.id,
            owner_id: owner_id
          )

        handle_ollama_result(photo, result, owner_id, state)

      {:error, reason} ->
        Logger.warning(
          "PhotoDescriptionWorker: Cannot read thumbnail for photo #{photo.id}: #{inspect(reason)}"
        )

        %{
          state
          | total_processed: state.total_processed + 1,
            total_failed: state.total_failed + 1
        }
    end
  end

  defp handle_ollama_result(photo, {:ok, %{"response" => response}, _server_url}, owner_id, state) do
    description = String.trim(response) |> String.slice(0, 2028)

    case Photos.update_photo_description(photo, %{
           description: description,
           description_generated_at: DateTime.utc_now(:second),
           description_model: @description_model
         }) do
      {:ok, _updated} ->
        ActivityLog.log(
          "system",
          "photo_description_generated",
          "Generated German description for photo #{photo.id}",
          subject_id: owner_id,
          metadata: %{
            "model" => @description_model,
            "description_length" => String.length(description)
          }
        )

        Logger.debug("PhotoDescriptionWorker: Generated description for photo #{photo.id}")

        %{
          state
          | total_processed: state.total_processed + 1,
            total_succeeded: state.total_succeeded + 1
        }

      {:error, changeset} ->
        Logger.warning(
          "PhotoDescriptionWorker: Failed to save description for photo #{photo.id}: #{inspect(changeset.errors)}"
        )

        %{
          state
          | total_processed: state.total_processed + 1,
            total_failed: state.total_failed + 1
        }
    end
  end

  defp handle_ollama_result(photo, {:error, reason}, _owner_id, state) do
    Logger.warning(
      "PhotoDescriptionWorker: Ollama failed for photo #{photo.id}: #{inspect(reason)}"
    )

    %{state | total_processed: state.total_processed + 1, total_failed: state.total_failed + 1}
  end
end
