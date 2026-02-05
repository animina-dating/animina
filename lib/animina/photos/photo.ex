defmodule Animina.Photos.Photo do
  @moduledoc """
  Schema for photos with a state machine for processing workflow.

  Photos are polymorphic — any schema can own photos via `owner_type` + `owner_id`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_states ~w(pending processing ollama_checking pending_ollama needs_manual_review approved no_face_error error appeal_pending appeal_rejected)
  @valid_transitions %{
    # "approved" is allowed for seeding/testing when skip_enqueue is used
    "pending" => ["processing", "error", "approved"],
    # Processing can go back to pending for recovery after restart
    "processing" => ["ollama_checking", "error", "pending"],
    # Ollama checking: uses simple prompt to check family_friendly, contains_person, person_facing_camera_count
    "ollama_checking" => [
      "approved",
      "no_face_error",
      "error",
      "pending",
      "pending_ollama",
      "needs_manual_review"
    ],
    # Pending Ollama state: waiting for retry
    "pending_ollama" => [
      "ollama_checking",
      "needs_manual_review",
      "approved",
      "no_face_error",
      "error"
    ],
    # Manual review: admin can approve, reject to error, or send back to retry queue
    "needs_manual_review" => [
      "approved",
      "error",
      "pending_ollama"
    ],
    "approved" => [],
    "no_face_error" => ["pending", "appeal_pending"],
    "error" => ["pending", "appeal_pending"],
    "appeal_pending" => ["approved", "appeal_rejected"],
    "appeal_rejected" => ["pending"]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "photos" do
    field :owner_type, :string
    field :owner_id, :binary_id
    field :type, :string
    field :state, :string, default: "pending"
    field :filename, :string
    field :original_filename, :string
    field :content_type, :string
    field :width, :integer
    field :height, :integer
    field :position, :integer, default: 0
    field :nsfw, :boolean, default: false
    field :nsfw_score, :float
    field :has_face, :boolean
    field :face_score, :float
    field :error_message, :string
    field :dhash, :binary

    # Ollama retry queue fields
    field :ollama_retry_count, :integer, default: 0
    field :ollama_retry_at, :utc_datetime
    field :ollama_check_type, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new photo record.
  """
  def create_changeset(photo, attrs) do
    photo
    |> cast(attrs, [
      :owner_type,
      :owner_id,
      :type,
      :filename,
      :original_filename,
      :content_type,
      :position
    ])
    |> validate_required([:owner_type, :owner_id, :filename])
    |> validate_inclusion(:state, @valid_states)
  end

  @doc """
  Changeset for transitioning to a new state.

  Enforces valid state transitions according to the state machine.
  """
  def transition_changeset(photo, new_state, attrs \\ %{}) do
    current_state = photo.state
    allowed = Map.get(@valid_transitions, current_state, [])

    if new_state in allowed do
      photo
      |> cast(attrs, [
        :width,
        :height,
        :nsfw,
        :nsfw_score,
        :has_face,
        :face_score,
        :error_message,
        :dhash,
        :ollama_retry_count,
        :ollama_retry_at,
        :ollama_check_type
      ])
      |> put_change(:state, new_state)
    else
      photo
      |> change()
      |> add_error(:state, "cannot transition from #{current_state} to #{new_state}")
    end
  end

  @doc """
  Returns the list of valid states.
  """
  def valid_states, do: @valid_states

  @doc """
  Returns the valid transitions map.
  """
  def valid_transitions, do: @valid_transitions
end
