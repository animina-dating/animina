defmodule Animina.Accounts.UserSessionTracker do
  @moduledoc """
  GenServer that tracks user online sessions by subscribing to
  Phoenix Presence diff events.

  On startup:
  1. Closes any stale open sessions from a previous boot
  2. Opens sessions for users currently online (handles GenServer restart)

  On presence_diff:
  - Joins: Opens a new session if the user doesn't already have one
  - Leaves: Closes the session if the user is fully offline (no more tabs)
  """

  use GenServer

  import Ecto.Query

  alias Animina.Accounts.UserOnlineSession
  alias Animina.Repo
  alias Animina.TimeMachine
  alias AniminaWeb.Presence

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to presence diffs
    Phoenix.PubSub.subscribe(Animina.PubSub, Presence.topic())

    # Close stale sessions from previous boot
    close_stale_sessions()

    # Open sessions for users already online (handles GenServer restart)
    reconcile_with_current_presence()

    {:ok, %{}}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff",
          payload: %{joins: joins, leaves: leaves}
        },
        state
      ) do
    handle_joins(joins)
    handle_leaves(leaves)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private ---

  defp handle_joins(joins) do
    for {user_id, _meta} <- joins do
      open_session_if_needed(user_id)
    end
  end

  defp handle_leaves(leaves) do
    for {user_id, _meta} <- leaves do
      # Only close if user is truly gone (no more tabs)
      unless Presence.user_online?(user_id) do
        close_open_session(user_id)
      end
    end
  end

  defp open_session_if_needed(user_id) do
    # Skip if already has an open session
    has_open =
      from(s in UserOnlineSession,
        where: s.user_id == ^user_id,
        where: is_nil(s.ended_at),
        select: 1,
        limit: 1
      )
      |> Repo.exists?()

    unless has_open do
      now = TimeMachine.utc_now() |> DateTime.truncate(:second)

      UserOnlineSession.open_changeset(%{user_id: user_id, started_at: now})
      |> Repo.insert()
    end
  end

  defp close_open_session(user_id) do
    case get_open_session(user_id) do
      nil ->
        :ok

      session ->
        session
        |> UserOnlineSession.close_changeset()
        |> Repo.update()
    end
  end

  defp get_open_session(user_id) do
    from(s in UserOnlineSession,
      where: s.user_id == ^user_id,
      where: is_nil(s.ended_at),
      order_by: [desc: s.started_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc false
  def close_stale_sessions do
    now = TimeMachine.utc_now() |> DateTime.truncate(:second)

    from(s in UserOnlineSession,
      where: is_nil(s.ended_at)
    )
    |> Repo.all()
    |> Enum.each(fn session ->
      duration = DateTime.diff(now, session.started_at, :second) |> div(60)

      session
      |> Ecto.Changeset.change(ended_at: now, duration_minutes: max(duration, 0))
      |> Repo.update()
    end)
  end

  defp reconcile_with_current_presence do
    now = TimeMachine.utc_now() |> DateTime.truncate(:second)

    online_user_ids =
      Presence.topic()
      |> Presence.list()
      |> Map.keys()

    for user_id <- online_user_ids do
      has_open =
        from(s in UserOnlineSession,
          where: s.user_id == ^user_id,
          where: is_nil(s.ended_at),
          select: 1,
          limit: 1
        )
        |> Repo.exists?()

      unless has_open do
        UserOnlineSession.open_changeset(%{user_id: user_id, started_at: now})
        |> Repo.insert()
      end
    end
  end
end
