defmodule Animina.Deployment do
  @moduledoc """
  Broadcasts deployment notifications to all connected LiveViews.

  Called via RPC from the deploy script just before a cold restart,
  so users see a friendly "Software update on the server" message instead of
  "Something went wrong!".
  """

  @topic "deployment:notifications"

  @doc """
  Broadcasts a deploying notification to all subscribers.

  The version is optional — when nil, the client falls back to a
  generic "Software update on the server" title.
  """
  def notify_deploying(version \\ nil) do
    Phoenix.PubSub.broadcast(Animina.PubSub, @topic, {:deploying, version})
  end

  @doc """
  Returns the PubSub topic for deployment notifications.
  """
  def topic, do: @topic
end
