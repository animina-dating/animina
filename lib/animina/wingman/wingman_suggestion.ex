defmodule Animina.Wingman.WingmanSuggestion do
  @moduledoc """
  Schema for AI-generated conversation coaching suggestions.

  Each record stores the suggestions generated for one user in one conversation,
  along with a context hash for staleness detection.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.AI.Job
  alias Animina.Messaging.Schemas.Conversation

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wingman_suggestions" do
    belongs_to :conversation, Conversation
    belongs_to :user, User
    belongs_to :ai_job, Job

    field :suggestions, {:array, :map}
    field :context_hash, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [
      :conversation_id,
      :user_id,
      :suggestions,
      :context_hash,
      :ai_job_id
    ])
    |> validate_required([:conversation_id, :user_id])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:ai_job_id)
    |> unique_constraint([:conversation_id, :user_id])
  end
end
