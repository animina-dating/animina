defmodule Animina.Messaging.Schemas.Conversation do
  @moduledoc """
  Schema for 1:1 conversations between users.

  Conversations are the container for messages and track the participants.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Messaging.Schemas.{ConversationParticipant, Message}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    has_many :participants, ConversationParticipant
    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [])
  end
end
