defmodule Animina.Accounts.UserOnlineSession do
  @moduledoc """
  Schema for tracking user online sessions.

  Each session represents a continuous period when a user had at least one
  connected LiveView. An open session (ended_at is nil) means the user is
  currently online.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.TimeMachine

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_online_sessions" do
    belongs_to :user, Animina.Accounts.User

    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :duration_minutes, :integer

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for opening a new session.
  """
  def open_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :started_at])
    |> validate_required([:user_id, :started_at])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for closing an open session.
  Sets ended_at and computes duration_minutes.
  """
  def close_changeset(session, ended_at \\ nil) do
    ended_at = ended_at || TimeMachine.utc_now() |> DateTime.truncate(:second)
    duration = DateTime.diff(ended_at, session.started_at, :second) |> div(60)

    session
    |> change(ended_at: ended_at, duration_minutes: max(duration, 0))
  end
end
