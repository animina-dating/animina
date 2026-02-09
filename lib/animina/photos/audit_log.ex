defmodule Animina.Photos.AuditLog do
  @moduledoc """
  Audit logging for photo-related events.
  """

  import Ecto.Query

  alias Animina.ActivityLog
  alias Animina.Photos.Photo
  alias Animina.Photos.PhotoAuditLog
  alias Animina.Repo

  @doc """
  Logs an event in the photo audit log.

  ## Options

    * `:duration_ms` - Duration of the operation in milliseconds
    * `:ollama_server_url` - URL of the Ollama server used (for Ollama-related events)
  """
  def log_event(
        %Photo{} = photo,
        event_type,
        actor_type,
        actor_id \\ nil,
        details \\ %{},
        opts \\ []
      ) do
    attrs = %{
      photo_id: photo.id,
      event_type: event_type,
      actor_type: actor_type,
      actor_id: actor_id,
      details: details,
      duration_ms: Keyword.get(opts, :duration_ms),
      ollama_server_url: Keyword.get(opts, :ollama_server_url)
    }

    result =
      %PhotoAuditLog{}
      |> PhotoAuditLog.create_changeset(attrs)
      |> Repo.insert()

    # Bridge key photo events to the unified activity log (best-effort, never fail the audit log)
    if event_type in ["photo_uploaded", "photo_approved", "photo_rejected"] do
      try do
        ActivityLog.log("system", event_type, "Photo #{event_type}: #{photo.id}",
          actor_id: actor_id,
          subject_id: photo.owner_id,
          metadata: %{"photo_id" => photo.id, "event_type" => event_type}
        )
      rescue
        _ -> :ok
      end
    end

    result
  end

  @doc """
  Gets the complete audit history for a photo.
  """
  def get_photo_history(photo_id) do
    PhotoAuditLog
    |> where([l], l.photo_id == ^photo_id)
    |> order_by([l], asc: l.inserted_at)
    |> preload(:actor)
    |> Repo.all()
  end

  @doc """
  Lists recent audit events across all photos.
  """
  def list_recent_events(limit \\ 100) do
    PhotoAuditLog
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload([:photo, :actor])
    |> Repo.all()
  end
end
