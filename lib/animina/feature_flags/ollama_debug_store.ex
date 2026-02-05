defmodule Animina.FeatureFlags.OllamaDebugStore do
  @moduledoc """
  ETS-based store for capturing Ollama API calls for debugging.

  When the :ollama_debug_display feature flag is enabled, this store
  captures recent Ollama API calls so admins can view them for debugging
  purposes.

  ## Usage

      # Store a call (typically done by OllamaClient)
      OllamaDebugStore.store_call(%{
        timestamp: DateTime.utc_now(),
        model: "qwen3-vl:8b",
        prompt: "...",
        images: ["base64..."],
        response: %{"response" => "..."},
        server_url: "http://localhost:11434/api",
        duration_ms: 1500,
        photo_id: "uuid",
        user_email: "user@example.com",
        user_display_name: "John Doe"
      })

      # Get recent calls for display
      calls = OllamaDebugStore.get_recent_calls()

  ## Live Updates

  Subscribes to PubSub topic `"ollama_debug:calls"` to receive new calls
  as they are stored. Messages are sent as `{:new_ollama_call, call}`.
  """

  use GenServer
  require Logger

  @table_name :ollama_debug_store
  @max_entries 500
  @default_max_age_seconds 3600
  @pubsub_topic "ollama_debug:calls"

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores an Ollama API call for debugging.

  The entry should contain:
  - timestamp: DateTime of the call
  - model: The Ollama model used
  - prompt: The prompt sent
  - images: List of base64-encoded images (truncated for display)
  - response: The response map or error
  - server_url: Which Ollama server handled the request
  - duration_ms: How long the call took
  - photo_id: The photo being processed
  - status: :success or :error
  """
  @spec store_call(map()) :: :ok
  def store_call(entry) do
    GenServer.cast(__MODULE__, {:store, entry})
  end

  @doc """
  Gets recent Ollama calls, most recent first.
  """
  @spec get_recent_calls(pos_integer()) :: [map()]
  def get_recent_calls(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_recent, limit})
  end

  @doc """
  Clears all stored entries.
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  @doc """
  Returns the PubSub topic for subscribing to new calls.
  """
  @spec pubsub_topic() :: String.t()
  def pubsub_topic, do: @pubsub_topic

  @doc """
  Manually trigger cleanup of old entries.
  """
  @spec cleanup(non_neg_integer()) :: :ok
  def cleanup(max_age_seconds \\ @default_max_age_seconds) do
    GenServer.cast(__MODULE__, {:cleanup, max_age_seconds})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:ordered_set, :named_table, :public, read_concurrency: true])

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{table: table, counter: 0}}
  end

  @impl true
  def handle_cast({:store, entry}, state) do
    counter = state.counter + 1

    # Use negative counter so highest counter (most recent) sorts first in ordered_set
    # Combined with timestamp for uniqueness
    key = {-counter, entry[:timestamp] || DateTime.utc_now()}

    # Truncate images to avoid storing massive base64 data
    entry = Map.update(entry, :images, [], fn images ->
      Enum.map(images || [], fn img ->
        if is_binary(img) and byte_size(img) > 100 do
          String.slice(img, 0, 100) <> "... [truncated, #{byte_size(img)} bytes total]"
        else
          img
        end
      end)
    end)

    :ets.insert(@table_name, {key, entry})

    # Keep only max_entries
    cleanup_excess()

    # Broadcast for live updates
    Phoenix.PubSub.broadcast(Animina.PubSub, @pubsub_topic, {:new_ollama_call, entry})

    {:noreply, %{state | counter: counter}}
  end

  @impl true
  def handle_cast({:cleanup, max_age_seconds}, state) do
    cutoff = DateTime.utc_now() |> DateTime.add(-max_age_seconds, :second)

    :ets.foldl(
      fn {key, entry}, acc ->
        if DateTime.compare(entry[:timestamp] || DateTime.utc_now(), cutoff) == :lt do
          :ets.delete(@table_name, key)
        end

        acc
      end,
      nil,
      @table_name
    )

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_recent, limit}, _from, state) do
    entries =
      @table_name
      |> :ets.tab2list()
      |> Enum.take(limit)
      |> Enum.map(fn {_key, entry} -> entry end)

    {:reply, entries, state}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, %{state | counter: 0}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up entries older than 1 hour
    cutoff = DateTime.utc_now() |> DateTime.add(-@default_max_age_seconds, :second)

    :ets.foldl(
      fn {key, entry}, acc ->
        if DateTime.compare(entry[:timestamp] || DateTime.utc_now(), cutoff) == :lt do
          :ets.delete(@table_name, key)
        end

        acc
      end,
      nil,
      @table_name
    )

    schedule_cleanup()
    {:noreply, state}
  end

  # --- Private Functions ---

  defp cleanup_excess do
    size = :ets.info(@table_name, :size)

    if size > @max_entries do
      # Get all keys, sorted (most recent first due to negative counter)
      keys =
        @table_name
        |> :ets.tab2list()
        |> Enum.map(fn {key, _} -> key end)
        |> Enum.sort()

      # Delete oldest entries (at the end of the sorted list)
      keys
      |> Enum.drop(@max_entries)
      |> Enum.each(fn key -> :ets.delete(@table_name, key) end)
    end
  end

  defp schedule_cleanup do
    # Clean up every 15 minutes
    Process.send_after(self(), :cleanup, 15 * 60 * 1000)
  end
end
