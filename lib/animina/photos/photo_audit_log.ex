defmodule Animina.Photos.PhotoAuditLog do
  @moduledoc """
  Schema for photo audit log entries.

  Records all significant events in a photo's lifecycle for complete traceability.
  Each event captures the actor (system, AI, user, moderator, admin) and relevant details.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Photos.Photo
  alias Animina.TimeMachine

  @valid_event_types ~w(
    photo_uploaded
    processing_started
    processing_completed
    blacklist_checked
    blacklist_matched
    nsfw_checked
    nsfw_escalated_ollama
    face_checked
    face_escalated_ollama
    photo_approved
    photo_rejected
    appeal_created
    appeal_approved
    appeal_rejected
    blacklist_added
    blacklist_removed
    recovery_after_restart
  )

  @valid_actor_types ~w(system ai user moderator admin)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "photo_audit_logs" do
    belongs_to :photo, Photo
    belongs_to :actor, User

    field :event_type, :string
    field :actor_type, :string
    field :details, :map, default: %{}

    # Performance tracking fields
    field :duration_ms, :integer
    field :ollama_server_url, :string

    field :inserted_at, :utc_datetime
  end

  @doc """
  Changeset for creating a new audit log entry.
  """
  def create_changeset(log, attrs) do
    log
    |> cast(attrs, [
      :photo_id,
      :event_type,
      :actor_type,
      :actor_id,
      :details,
      :duration_ms,
      :ollama_server_url
    ])
    |> validate_required([:photo_id, :event_type, :actor_type])
    |> validate_inclusion(:event_type, @valid_event_types)
    |> validate_inclusion(:actor_type, @valid_actor_types)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> put_change(:inserted_at, TimeMachine.utc_now(:second))
    |> foreign_key_constraint(:photo_id)
    |> foreign_key_constraint(:actor_id)
  end

  @doc """
  Returns the list of valid event types.
  """
  def valid_event_types, do: @valid_event_types

  @doc """
  Returns the list of valid actor types.
  """
  def valid_actor_types, do: @valid_actor_types
end
