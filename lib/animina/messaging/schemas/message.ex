defmodule Animina.Messaging.Schemas.Message do
  @moduledoc """
  Schema for messages within a conversation.

  Messages support:
  - Markdown content
  - Edit tracking (edited_at)
  - Soft deletion (deleted_at)
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Messaging.Schemas.Conversation

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    belongs_to :conversation, Conversation
    belongs_to :sender, User

    field :content, :string
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @max_content_length 10_000

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :sender_id, :content])
    |> validate_required([:conversation_id, :sender_id, :content])
    |> validate_length(:content, min: 1, max: @max_content_length)
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:sender_id)
  end

  def edit_changeset(message, new_content) do
    message
    |> change(content: new_content, edited_at: DateTime.utc_now(:second))
    |> validate_length(:content, min: 1, max: @max_content_length)
  end

  def delete_changeset(message) do
    change(message, deleted_at: DateTime.utc_now(:second))
  end
end
