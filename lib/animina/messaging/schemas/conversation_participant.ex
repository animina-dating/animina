defmodule Animina.Messaging.Schemas.ConversationParticipant do
  @moduledoc """
  Schema for conversation participants.

  Tracks each user's involvement in a conversation, including:
  - last_read_at: For read receipts
  - blocked_at: For blocking within a conversation
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Messaging.Schemas.Conversation
  alias Animina.TimeMachine

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversation_participants" do
    belongs_to :conversation, Conversation
    belongs_to :user, User

    field :last_read_at, :utc_datetime
    field :blocked_at, :utc_datetime
    field :draft_content, :string
    field :draft_updated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:conversation_id, :user_id, :last_read_at, :blocked_at])
    |> validate_required([:conversation_id, :user_id])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:conversation_id, :user_id])
  end

  def mark_read_changeset(participant) do
    change(participant, last_read_at: TimeMachine.utc_now(:second))
  end

  def block_changeset(participant) do
    change(participant, blocked_at: TimeMachine.utc_now(:second))
  end

  def unblock_changeset(participant) do
    change(participant, blocked_at: nil)
  end

  def draft_changeset(participant, content) do
    if content == nil || content == "" do
      change(participant, draft_content: nil, draft_updated_at: nil)
    else
      change(participant, draft_content: content, draft_updated_at: TimeMachine.utc_now(:second))
    end
  end
end
