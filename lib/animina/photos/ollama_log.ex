defmodule Animina.Photos.OllamaLog do
  @moduledoc """
  Schema for logging every Ollama API call.

  Records the prompt, result, duration, model, and status for each call,
  along with the photo being analyzed and who triggered it.

  - `owner_id`: The user who owns the photo
  - `requester_id`: Who triggered the check (nil for automated pipeline, admin ID for manual re-runs)
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Photos.Photo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ollama_logs" do
    belongs_to :photo, Photo
    belongs_to :owner, User
    belongs_to :requester, User

    field :prompt, :string
    field :result, :string
    field :duration_ms, :integer
    field :model, :string
    field :server_url, :string
    field :status, :string
    field :error, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields [:status]
  @optional_fields [
    :photo_id,
    :owner_id,
    :requester_id,
    :prompt,
    :result,
    :duration_ms,
    :model,
    :server_url,
    :error
  ]

  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ["in_progress", "success", "error"])
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:photo_id)
    |> foreign_key_constraint(:owner_id)
    |> foreign_key_constraint(:requester_id)
  end
end
