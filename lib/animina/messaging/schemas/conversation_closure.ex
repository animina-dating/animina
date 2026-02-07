defmodule Animina.Messaging.Schemas.ConversationClosure do
  @moduledoc """
  Schema for tracking conversation closures ("Let go").

  Provides an audit trail for when conversations are closed and potentially
  reopened via Love Emergency. Each closure creates two records — one per
  participant's perspective (closed_by_id vs other_user_id).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Messaging.Schemas.Conversation
  alias Animina.TimeMachine

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversation_closures" do
    belongs_to :conversation, Conversation
    belongs_to :closed_by, User
    belongs_to :other_user, User

    field :reopened_at, :utc_datetime
    belongs_to :reopened_by, User

    timestamps(type: :utc_datetime)
  end

  def changeset(closure, attrs) do
    closure
    |> cast(attrs, [:conversation_id, :closed_by_id, :other_user_id])
    |> validate_required([:conversation_id, :closed_by_id, :other_user_id])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:closed_by_id)
    |> foreign_key_constraint(:other_user_id)
    |> unique_constraint([:conversation_id, :closed_by_id])
  end

  def reopen_changeset(closure, reopened_by_id) do
    closure
    |> change(reopened_at: TimeMachine.utc_now(:second), reopened_by_id: reopened_by_id)
  end
end
