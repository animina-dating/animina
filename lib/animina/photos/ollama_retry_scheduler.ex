defmodule Animina.Photos.OllamaRetryScheduler do
  @moduledoc """
  GenServer that polls for photos due for Ollama retry and processes them.

  Uses increasing backoff intervals (15 * retry_count minutes) to spread
  20 retry attempts across approximately 48 hours.

  After 20 failed attempts, photos are moved to `needs_manual_review` state.

  Also monitors queue size and sends email alerts when threshold is exceeded.
  """

  use GenServer
  require Logger

  alias Animina.Accounts.UserNotifier
  alias Animina.Photos
  alias Animina.Photos.OllamaClient
  alias Animina.Photos.OllamaHealthTracker
  alias Animina.Photos.Photo
  alias Animina.Photos.PhotoProcessor

  @poll_interval_ms 60_000
  @alert_threshold 20
  @alert_cooldown_ms 3_600_000

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the current queue statistics.
  """
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats)
  end

  @doc """
  Triggers an immediate poll for due photos (for testing).
  """
  def trigger_poll(server \\ __MODULE__) do
    GenServer.cast(server, :poll)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)
    alert_threshold = Keyword.get(opts, :alert_threshold, @alert_threshold)

    state = %{
      poll_interval: poll_interval,
      alert_threshold: alert_threshold,
      last_alert_at: nil,
      total_processed: 0,
      total_succeeded: 0,
      total_failed: 0
    }

    # Schedule first poll after startup delay
    Process.send_after(self(), :poll, 5_000)

    Logger.info(
      "OllamaRetryScheduler started with poll_interval=#{poll_interval}ms, alert_threshold=#{alert_threshold}"
    )

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state = do_poll(state)

    # Schedule next poll
    Process.send_after(self(), :poll, state.poll_interval)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:poll, state) do
    new_state = do_poll(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    queue_count = Photos.count_ollama_queue()

    stats = %{
      queue_count: queue_count,
      total_processed: state.total_processed,
      total_succeeded: state.total_succeeded,
      total_failed: state.total_failed,
      last_alert_at: state.last_alert_at
    }

    {:reply, stats, state}
  end

  # --- Private Functions ---

  defp do_poll(state) do
    # Get photos due for retry (one at a time to avoid overwhelming Ollama)
    photos = Photos.list_photos_due_for_ollama_retry(1)

    state =
      Enum.reduce(photos, state, fn photo, acc ->
        process_retry(photo, acc)
      end)

    # Check queue size and maybe send alert
    check_queue_alert(state)
  end

  defp process_retry(%Photo{} = photo, state) do
    Logger.debug(
      "Processing Ollama retry for photo #{photo.id}, attempt #{photo.ollama_retry_count}"
    )

    result = retry_check(photo)

    case result do
      {:ok, _photo} ->
        %{
          state
          | total_processed: state.total_processed + 1,
            total_succeeded: state.total_succeeded + 1
        }

      {:error, :ollama_unavailable} ->
        # Ollama still unavailable, queue for next retry
        requeue_photo(photo)

        %{
          state
          | total_processed: state.total_processed + 1,
            total_failed: state.total_failed + 1
        }

      {:error, reason} ->
        Logger.warning("Ollama retry failed for photo #{photo.id}: #{inspect(reason)}")

        %{
          state
          | total_processed: state.total_processed + 1,
            total_failed: state.total_failed + 1
        }
    end
  end

  defp retry_check(%Photo{} = photo) do
    # Return to checking state first
    case Photos.return_to_ollama_checking(photo) do
      {:ok, photo} ->
        run_ollama_classification(photo)

      error ->
        error
    end
  end

  defp run_ollama_classification(%Photo{} = photo) do
    ollama_model = Photos.ollama_model()
    thumbnail_path = Photos.processed_path(photo.id, :thumbnail)

    image_data = File.read!(thumbnail_path) |> Base.encode64()

    prompt = """
    You are an image classifier. Given the image, respond with JSON: { "contains_person": true/false, "person_facing_camera_count": number, "family_friendly": true/false } Check if the image shows exactly one person and if the content is appropriate for all ages.
    """

    {duration_us, result} =
      :timer.tc(fn ->
        OllamaClient.completion(model: ollama_model, prompt: prompt, images: [image_data])
      end)

    duration_ms = div(duration_us, 1000)

    case result do
      {:ok, %{"response" => response}, server_url} ->
        # Log Ollama response in development
        if Application.get_env(:animina, :env) == :dev do
          Logger.info("Ollama retry response for photo #{photo.id}: #{response}")
        end

        parsed = PhotoProcessor.parse_ollama_response(response)

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
            via: "retry_scheduler"
          },
          duration_ms: duration_ms,
          ollama_server_url: server_url
        )

        finalize_check(photo, parsed)

      {:error, _reason} ->
        {:error, :ollama_unavailable}
    end
  end

  defp finalize_check(photo, parsed) do
    # Build attrs - clear retry fields on completion
    base_attrs = %{
      ollama_retry_count: 0,
      ollama_retry_at: nil,
      ollama_check_type: nil,
      ollama_bumblebee_score: nil
    }

    cond do
      not parsed.family_friendly ->
        # Not family friendly - reject and blacklist
        maybe_auto_blacklist(photo)

        Photos.log_event(photo, "photo_rejected", "system", nil, %{
          reason: "not_family_friendly",
          state: "error"
        })

        Photos.transition_photo(
          photo,
          "error",
          Map.put(base_attrs, :error_message, "Content is not family friendly")
        )

      not parsed.contains_person or parsed.person_facing_camera_count != 1 ->
        # No person or not exactly one person facing camera - reject
        Photos.log_event(photo, "photo_rejected", "system", nil, %{
          reason: "no_face_detected",
          contains_person: parsed.contains_person,
          person_facing_camera_count: parsed.person_facing_camera_count,
          state: "no_face_error"
        })

        Photos.transition_photo(
          photo,
          "no_face_error",
          Map.put(
            base_attrs,
            :error_message,
            "Photo must show exactly one person facing the camera"
          )
        )

      true ->
        # All checks passed - approve
        Photos.transition_photo(photo, "approved", base_attrs)
    end
  end

  defp maybe_auto_blacklist(%Photo{dhash: nil}), do: :ok

  defp maybe_auto_blacklist(%Photo{dhash: dhash} = photo) do
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

  defp requeue_photo(%Photo{} = photo) do
    Photos.queue_for_ollama_retry(photo, 0.5)
  end

  defp check_queue_alert(state) do
    queue_count = Photos.count_ollama_queue()

    if queue_count > state.alert_threshold && should_send_alert?(state) do
      send_queue_alert(queue_count, state)
    else
      state
    end
  end

  defp should_send_alert?(state) do
    case state.last_alert_at do
      nil ->
        true

      last_alert_at ->
        elapsed = DateTime.diff(DateTime.utc_now(), last_alert_at, :millisecond)
        elapsed >= @alert_cooldown_ms
    end
  end

  defp send_queue_alert(queue_count, state) do
    oldest_photo = Photos.get_oldest_ollama_queue_photo()

    oldest_age =
      if oldest_photo do
        DateTime.diff(DateTime.utc_now(), oldest_photo.inserted_at, :hour)
      else
        0
      end

    # Get Ollama health status
    ollama_status = get_ollama_health_status()

    stats = %{
      queue_count: queue_count,
      oldest_photo_age_hours: oldest_age,
      ollama_status: ollama_status
    }

    case UserNotifier.deliver_ollama_queue_alert(stats) do
      {:ok, _email} ->
        Logger.warning("Ollama queue alert sent: #{queue_count} photos waiting")
        %{state | last_alert_at: DateTime.utc_now()}

      {:error, reason} ->
        Logger.error("Failed to send Ollama queue alert: #{inspect(reason)}")
        state
    end
  end

  defp get_ollama_health_status do
    statuses = OllamaHealthTracker.get_all_statuses()

    healthy_count = Enum.count(statuses, fn {_url, status} -> status.state == :closed end)
    total = length(statuses)

    "#{healthy_count}/#{total} healthy"
  rescue
    _ -> "unknown"
  end
end
