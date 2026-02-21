defmodule Animina.AI.Job do
  @moduledoc """
  Schema for AI jobs — the unified queue for all AI processing tasks.

  Each job represents a unit of work to be executed by an AI model (Ollama),
  such as photo classification, gender guessing, or photo description generation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_job_types ~w(photo_classification gender_guess photo_description wingman_suggestion)
  @valid_statuses ~w(pending scheduled running completed failed cancelled paused)

  schema "ai_jobs" do
    field :job_type, :string
    field :priority, :integer
    field :status, :string, default: "pending"
    field :error, :string
    field :attempt, :integer, default: 0
    field :max_attempts, :integer, default: 20
    field :scheduled_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :params, :map
    field :result, :map
    field :model, :string
    field :server_url, :string
    field :prompt, :string
    field :raw_response, :string
    field :duration_ms, :integer
    field :subject_type, :string
    field :subject_id, :binary_id

    belongs_to :requester, User

    timestamps(type: :utc_datetime)
  end

  def valid_job_types, do: @valid_job_types
  def valid_statuses, do: @valid_statuses

  @doc """
  Changeset for creating a new AI job.
  """
  def create_changeset(job, attrs) do
    job
    |> cast(attrs, [
      :job_type,
      :priority,
      :status,
      :max_attempts,
      :scheduled_at,
      :expires_at,
      :params,
      :model,
      :subject_type,
      :subject_id,
      :requester_id
    ])
    |> validate_required([:job_type, :priority, :params])
    |> validate_inclusion(:job_type, @valid_job_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:priority, greater_than: 0, less_than_or_equal_to: 5)
    |> foreign_key_constraint(:requester_id)
  end

  @doc """
  Changeset for updating a job during execution.
  """
  def update_changeset(job, attrs) do
    job
    |> cast(attrs, [
      :status,
      :error,
      :attempt,
      :scheduled_at,
      :result,
      :model,
      :server_url,
      :prompt,
      :raw_response,
      :duration_ms
    ])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
  end

  @doc """
  Changeset for admin actions (cancel, reprioritize, pause).
  """
  def admin_changeset(job, attrs) do
    job
    |> cast(attrs, [:status, :priority, :scheduled_at, :error])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:priority, greater_than: 0, less_than_or_equal_to: 5)
  end
end
