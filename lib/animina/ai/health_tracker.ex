defmodule Animina.AI.HealthTracker do
  @moduledoc """
  GenServer that tracks health and performance of Ollama instances.

  Circuit States:
  - :closed - Instance is healthy, requests pass through
  - :open - Instance is unhealthy (after N failures), requests skip this instance
  - :half_open - Testing if instance recovered (after cooldown period)

  Performance Tracking:
  - avg_duration_ms: Exponential moving average (EMA, alpha=0.3) of request durations
  - job_count: Total completed jobs per instance
  - tags: Instance capability tags (e.g., ["gpu"], ["cpu"])
  """

  use GenServer
  require Logger

  alias Animina.AI

  @ema_alpha 0.3

  defstruct [:state, :failure_count, :last_failure_at, :avg_duration_ms, :job_count, :tags]

  @type circuit_state :: :closed | :open | :half_open

  @type instance_status :: %__MODULE__{
          state: circuit_state(),
          failure_count: non_neg_integer(),
          last_failure_at: DateTime.t() | nil,
          avg_duration_ms: float() | nil,
          job_count: non_neg_integer(),
          tags: [String.t()]
        }

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a successful request, updating circuit breaker and EMA duration.
  """
  @spec record_success(String.t(), non_neg_integer() | nil) :: :ok
  def record_success(url, duration_ms \\ nil) do
    GenServer.cast(__MODULE__, {:record_success, url, duration_ms})
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

  @doc """
  Returns all instances with their full health + performance stats.
  """
  @spec get_instance_stats(GenServer.server()) :: [map()]
  def get_instance_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_instance_stats)
  end

  @doc """
  Returns instances that have a specific tag.
  """
  @spec get_instances_by_tag(GenServer.server(), String.t()) :: [map()]
  def get_instances_by_tag(server \\ __MODULE__, tag) do
    GenServer.call(server, {:get_instances_by_tag, tag})
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    threshold = Keyword.get(opts, :threshold, AI.config(:ollama_circuit_breaker_threshold, 3))
    reset_ms = Keyword.get(opts, :reset_ms, AI.config(:ollama_circuit_breaker_reset_ms, 60_000))
    instances = Keyword.get_lazy(opts, :instances, fn -> get_instance_data() end)

    initial_statuses =
      instances
      |> Enum.map(fn {url, tags} ->
        {url,
         %__MODULE__{
           state: :closed,
           failure_count: 0,
           last_failure_at: nil,
           avg_duration_ms: nil,
           job_count: 0,
           tags: tags
         }}
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
  def handle_cast({:record_success, url, duration_ms}, state) do
    new_state = update_status(state, url, &close_circuit(&1, duration_ms))
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

  @impl true
  def handle_call(:get_instance_stats, _from, state) do
    stats =
      Enum.map(state.statuses, fn {url, status} ->
        %{
          url: url,
          state: status.state,
          failure_count: status.failure_count,
          avg_duration_ms: status.avg_duration_ms,
          job_count: status.job_count,
          tags: status.tags
        }
      end)

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:get_instances_by_tag, tag}, _from, state) do
    matching =
      state.statuses
      |> Enum.filter(fn {_url, status} -> tag in status.tags end)
      |> Enum.map(fn {url, status} ->
        %{
          url: url,
          state: status.state,
          avg_duration_ms: status.avg_duration_ms,
          job_count: status.job_count,
          tags: status.tags
        }
      end)

    {:reply, matching, state}
  end

  # --- Private Functions ---

  defp update_status(state, url, update_fn) do
    case Map.get(state.statuses, url) do
      nil ->
        state

      status ->
        updated_status = update_fn.(status)
        %{state | statuses: Map.put(state.statuses, url, updated_status)}
    end
  end

  defp close_circuit(%__MODULE__{} = status, duration_ms) do
    new_avg = update_ema(status.avg_duration_ms, duration_ms)

    %__MODULE__{
      status
      | state: :closed,
        failure_count: 0,
        last_failure_at: nil,
        avg_duration_ms: new_avg,
        job_count: status.job_count + 1
    }
  end

  defp update_ema(_old_avg, nil), do: nil

  defp update_ema(nil, duration_ms) when is_number(duration_ms),
    do: duration_ms / 1

  defp update_ema(old_avg, duration_ms) when is_number(duration_ms),
    do: @ema_alpha * duration_ms + (1 - @ema_alpha) * old_avg

  defp increment_failure(%__MODULE__{} = status, threshold) do
    new_count = status.failure_count + 1
    now = DateTime.utc_now()

    new_state =
      cond do
        status.state == :open ->
          :open

        status.state == :half_open ->
          :open

        new_count >= threshold ->
          Logger.warning("Circuit opened after #{new_count} failures (threshold: #{threshold})")
          :open

        true ->
          :closed
      end

    %__MODULE__{
      status
      | state: new_state,
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

  defp get_instance_data do
    alias Animina.AI.Client

    default_tags = AI.config(:ollama_default_tags, ["gpu"])

    Client.ollama_instances()
    |> Enum.sort_by(& &1.priority)
    |> Enum.map(fn inst -> {inst.url, Map.get(inst, :tags, default_tags)} end)
  end
end
