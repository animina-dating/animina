defmodule Animina.AI.HealthTracker do
  @moduledoc """
  GenServer that tracks health of Ollama instances using a circuit breaker pattern.

  Circuit States:
  - :closed - Instance is healthy, requests pass through
  - :open - Instance is unhealthy (after N failures), requests skip this instance
  - :half_open - Testing if instance recovered (after cooldown period)

  The tracker maintains state for each configured Ollama instance URL and
  transitions between states based on success/failure signals from the Client.
  """

  use GenServer
  require Logger

  alias Animina.AI

  defstruct [:state, :failure_count, :last_failure_at]

  @type circuit_state :: :closed | :open | :half_open

  @type instance_status :: %__MODULE__{
          state: circuit_state(),
          failure_count: non_neg_integer(),
          last_failure_at: DateTime.t() | nil
        }

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec record_success(GenServer.server(), String.t()) :: :ok
  def record_success(server \\ __MODULE__, url) do
    GenServer.cast(server, {:record_success, url})
  end

  @spec record_failure(GenServer.server(), String.t(), term()) :: :ok
  def record_failure(server \\ __MODULE__, url, reason) do
    GenServer.cast(server, {:record_failure, url, reason})
  end

  @spec get_healthy_instances(GenServer.server()) :: [String.t()]
  def get_healthy_instances(server \\ __MODULE__) do
    GenServer.call(server, :get_healthy_instances)
  end

  @spec get_all_statuses(GenServer.server()) :: [{String.t(), instance_status()}]
  def get_all_statuses(server \\ __MODULE__) do
    GenServer.call(server, :get_all_statuses)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    threshold = Keyword.get(opts, :threshold, AI.config(:ollama_circuit_breaker_threshold, 3))
    reset_ms = Keyword.get(opts, :reset_ms, AI.config(:ollama_circuit_breaker_reset_ms, 60_000))
    instances = Keyword.get_lazy(opts, :instances, fn -> get_instance_urls() end)

    initial_statuses =
      instances
      |> Enum.map(fn url ->
        {url, %__MODULE__{state: :closed, failure_count: 0, last_failure_at: nil}}
      end)
      |> Map.new()

    state = %{
      statuses: initial_statuses,
      threshold: threshold,
      reset_ms: reset_ms
    }

    Logger.info(
      "AI.HealthTracker started with #{length(instances)} instance(s), threshold=#{threshold}, reset_ms=#{reset_ms}"
    )

    {:ok, state}
  end

  @impl true
  def handle_cast({:record_success, url}, state) do
    new_state = update_status(state, url, &close_circuit/1)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:record_failure, url, reason}, state) do
    Logger.debug("AI instance #{url} failed: #{inspect(reason)}")
    new_state = update_status(state, url, &increment_failure(&1, state.threshold))
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_healthy_instances, _from, state) do
    now = DateTime.utc_now()

    {updated_statuses, healthy_urls} =
      Enum.reduce(state.statuses, {%{}, []}, fn {url, status}, {statuses_acc, urls_acc} ->
        updated_status = maybe_transition_to_half_open(status, now, state.reset_ms)
        updated_statuses = Map.put(statuses_acc, url, updated_status)

        if updated_status.state in [:closed, :half_open] do
          {updated_statuses, [url | urls_acc]}
        else
          {updated_statuses, urls_acc}
        end
      end)

    sorted_urls = Enum.sort(healthy_urls)

    {:reply, sorted_urls, %{state | statuses: updated_statuses}}
  end

  @impl true
  def handle_call(:get_all_statuses, _from, state) do
    result = Enum.to_list(state.statuses)
    {:reply, result, state}
  end

  # --- Private Functions ---

  defp update_status(state, url, update_fn) do
    case Map.get(state.statuses, url) do
      nil -> state
      status ->
        updated_status = update_fn.(status)
        %{state | statuses: Map.put(state.statuses, url, updated_status)}
    end
  end

  defp close_circuit(_status) do
    %__MODULE__{state: :closed, failure_count: 0, last_failure_at: nil}
  end

  defp increment_failure(status, threshold) do
    new_count = status.failure_count + 1
    now = DateTime.utc_now()

    new_state =
      cond do
        status.state == :open -> :open
        status.state == :half_open -> :open
        new_count >= threshold ->
          Logger.warning("Circuit opened after #{new_count} failures (threshold: #{threshold})")
          :open
        true -> :closed
      end

    %__MODULE__{
      state: new_state,
      failure_count: new_count,
      last_failure_at: now
    }
  end

  defp maybe_transition_to_half_open(%__MODULE__{state: :open} = status, now, reset_ms) do
    case status.last_failure_at do
      nil ->
        status

      last_failure_at ->
        elapsed_ms = DateTime.diff(now, last_failure_at, :millisecond)

        if elapsed_ms >= reset_ms do
          Logger.info("Circuit transitioning to half-open after #{elapsed_ms}ms cooldown")
          %__MODULE__{status | state: :half_open}
        else
          status
        end
    end
  end

  defp maybe_transition_to_half_open(status, _now, _reset_ms), do: status

  defp get_instance_urls do
    Animina.AI.Client.ollama_instances()
    |> Enum.sort_by(& &1.priority)
    |> Enum.map(& &1.url)
  end
end
