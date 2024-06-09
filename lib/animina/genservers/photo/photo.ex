defmodule Animina.GenServers.Photo do
  @moduledoc """
  This is the genserver that handles uploaded photos processing
  """

  use GenStage

  require Ash.Query
  alias Animina.Accounts
  alias Animina.Accounts.Photo

  @doc """
  Starts a GenStage process linked to the current process.
  """
  def start_link do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Starts a GenStage process linked to the current process.
  """
  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Starts a queue which manages files to be processed
  """
  @impl true
  def init(_) do
    schedule_fetch_unprocessed_photos()

    queue = :queue.new()
    {:producer, {queue, 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl true
  def handle_call({:notify, photo}, from, {queue, pending_demand}) do
    queue = :queue.in({from, photo}, queue)
    dispatch_photos(queue, pending_demand, [])
  end

  @impl true
  def handle_info({:fetch_unprocessed_photos, _from}, {queue, pending_demand}) do
    schedule_fetch_unprocessed_photos()

    bulk_result =
      Photo
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(created_at: :asc)
      |> Ash.Query.filter(state == ^:pending_review)
      |> Accounts.read!(authorize?: false, page: [limit: 6])

    queue =
      Enum.reduce(bulk_result.results, queue, fn photo, acc ->
        :queue.in({nil, photo}, acc)
      end)

    dispatch_photos(queue, pending_demand, [])
  end

  @doc """
  Handles photos demand from photo consumers
  """
  @impl true
  def handle_demand(incoming_demand, {queue, pending_demand}) do
    dispatch_photos(queue, incoming_demand + pending_demand, [])
  end

  defp schedule_fetch_unprocessed_photos do
    Process.send_after(self(), {:fetch_unprocessed_photos, self()}, 30_000)
  end

  @doc """
  Adds a photo to this producer for processing
  """
  def add_photo(photo, timeout \\ 10_000) do
    GenStage.call(__MODULE__, {:notify, photo}, timeout)
  end

  defp dispatch_photos(queue, 0, photos) do
    {:noreply, Enum.reverse(photos), {queue, 0}}
  end

  defp dispatch_photos(queue, demand, photos) do
    case :queue.out(queue) do
      {{:value, {from, photo}}, queue} ->
        if is_nil(from) == false do
          GenStage.reply(from, :ok)
        end

        dispatch_photos(queue, demand - 1, [photo | photos])

      {:empty, queue} ->
        {:noreply, Enum.reverse(photos), {queue, demand}}
    end
  end
end
