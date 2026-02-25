defmodule Animina.Wingman.WingmanSuggestion do
  @moduledoc """
  Schema for AI-generated conversation coaching suggestions.

  Dual-mode storage:
  - **On-demand**: `conversation_id` is set — suggestions for an open chat panel.
  - **Preheated**: `conversation_id` is NULL, `other_user_id` + `shown_on` are set —
    pre-computed hints for today's spotlight profiles.
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
    belongs_to :other_user, User
    belongs_to :ai_job, Job

    field :suggestions, {:array, :map}
    field :context_hash, :string
    field :shown_on, :date

    timestamps(type: :utc_datetime)
  end

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [
      :conversation_id,
      :user_id,
      :other_user_id,
      :shown_on,
      :suggestions,
      :context_hash,
      :ai_job_id
    ])
    |> validate_required([:user_id])
    |> validate_mode()
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:other_user_id)
    |> foreign_key_constraint(:ai_job_id)
    |> unique_constraint([:conversation_id, :user_id],
      name: :wingman_suggestions_conversation_user_unique
    )
    |> unique_constraint([:user_id, :other_user_id, :shown_on],
      name: :wingman_suggestions_preheated_unique
    )
  end

  # Either conversation_id is present (on-demand), or both other_user_id + shown_on (preheated)
  defp validate_mode(changeset) do
    conv_id = get_field(changeset, :conversation_id)
    other_id = get_field(changeset, :other_user_id)
    shown_on = get_field(changeset, :shown_on)

    cond do
      not is_nil(conv_id) ->
        changeset

      not is_nil(other_id) and not is_nil(shown_on) ->
        changeset

      true ->
        add_error(
          changeset,
          :conversation_id,
          "either conversation_id or other_user_id + shown_on must be set"
        )
    end
  end
end
