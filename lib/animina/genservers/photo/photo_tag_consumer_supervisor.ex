defmodule Animina.GenServers.PhotoTagConsumerSupervisor do
  @moduledoc """
  Manages consumers that process photos
  """

  use ConsumerSupervisor

  @doc """
  Starts a Genstage consumer process that processes a photo
  """
  def start_link(_args) do
    ConsumerSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_link do
    ConsumerSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      %{
        id: Animina.GenServers.PhotoConsumer,
        start: {Animina.GenServers.PhotoTagConsumer, :start_link, []},
        restart: :transient
      }
    ]

    opts = [
      strategy: :one_for_one,
      subscribe_to: [{Animina.GenServers.Photo, max_demand: 6}]
    ]

    ConsumerSupervisor.init(children, opts)
  end
end
