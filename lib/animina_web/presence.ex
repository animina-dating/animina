defmodule AniminaWeb.Presence do
  @moduledoc """
  Tracks authenticated online users via Phoenix Presence.
  """

  use Phoenix.Presence,
    otp_app: :animina,
    pubsub_server: Animina.PubSub

  @topic "online_users"

  def topic, do: @topic

  @doc """
  Returns the count of unique online users.
  """
  def online_user_count do
    @topic
    |> list()
    |> map_size()
  end

  @doc """
  Tracks a user's LiveView process in Presence.
  """
  def track_user(pid, user_id) do
    track(pid, @topic, user_id, %{joined_at: System.system_time(:second)})
  end
end
