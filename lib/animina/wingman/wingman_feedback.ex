defmodule Animina.Wingman.WingmanFeedback do
  @moduledoc """
  Schema for user feedback on Wingman suggestions.

  Each record stores whether a user liked (+1) or disliked (-1) a specific
  suggestion. The suggestion text is stored with the feedback since suggestions
  are ephemeral and deleted after the first message is sent.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Messaging.Schemas.Conversation

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wingman_feedbacks" do
    belongs_to :conversation, Conversation
    belongs_to :user, User

    field :suggestion_index, :integer
    field :suggestion_text, :string
    field :suggestion_hook, :string
    field :value, :integer
    field :wingman_style, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [
      :user_id,
      :conversation_id,
      :suggestion_index,
      :suggestion_text,
      :suggestion_hook,
      :value,
      :wingman_style
    ])
    |> validate_required([:user_id, :conversation_id, :suggestion_index, :suggestion_text, :value])
    |> validate_inclusion(:value, [-1, 1])
    |> validate_inclusion(:suggestion_index, [0, 1])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:conversation_id)
    |> unique_constraint([:user_id, :conversation_id, :suggestion_index])
  end
end
