defmodule Animina.AI.Autoscaler do
  @moduledoc """
  Response-time-based autoscaler for AI concurrency.

  Tracks a rolling window of recent response times and adjusts the
  Semaphore's max concurrent slots between a configured min and max.

  - If median response time < up_threshold → increase max by 1
  - If median response time > down_threshold → decrease max by 1
  - Cooldown period between adjustments to avoid oscillation
  """

  use GenServer
  require Logger

  alias Animina.AI.Semaphore
  alias Animina.FeatureFlags

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Reports a completed job duration for autoscaling decisions.
  """
  def report_duration(duration_ms, server \\ __MODULE__) do
    GenServer.cast(server, {:report_duration, duration_ms})
  end

  @doc """
  Returns the current autoscaler state for monitoring.
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    state = %{
      window: [],
      window_size: Keyword.get(opts, :window_size, read_setting(:ai_autoscale_window_size, 20)),
      min_slots: Keyword.get(opts, :min_slots, read_setting(:ai_autoscale_min, 2)),
      max_slots: Keyword.get(opts, :max_slots, read_setting(:ai_autoscale_max, 10)),
      up_threshold_ms:
        Keyword.get(
          opts,
          :up_threshold_ms,
          read_setting(:ai_autoscale_up_threshold_ms, 10_000)
        ),
      down_threshold_ms:
        Keyword.get(
          opts,
          :down_threshold_ms,
          read_setting(:ai_autoscale_down_threshold_ms, 30_000)
        ),
      cooldown_ms:
        Keyword.get(opts, :cooldown_ms, read_setting(:ai_autoscale_cooldown_ms, 30_000)),
      current_max: Keyword.get(opts, :initial_max, read_setting(:ai_autoscale_min, 2)),
      last_adjustment_at: nil,
      semaphore: Keyword.get(opts, :semaphore, Semaphore)
    }

    Logger.info(
      "AI.Autoscaler started: slots #{state.min_slots}-#{state.max_slots}, " <>
        "up<#{state.up_threshold_ms}ms, down>#{state.down_threshold_ms}ms"
    )

    {:ok, state}
  end

  @impl true
  def handle_cast({:report_duration, duration_ms}, state) do
    # Add to rolling window
    window = [duration_ms | state.window] |> Enum.take(state.window_size)
    state = %{state | window: window}

    # Only evaluate if we have enough data
    state =
      if length(window) >= 3 do
        maybe_adjust(state)
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    info = %{
      current_max: state.current_max,
      min_slots: state.min_slots,
      max_slots: state.max_slots,
      window_size: length(state.window),
      median_ms: if(state.window != [], do: median(state.window), else: nil),
      last_adjustment_at: state.last_adjustment_at
    }

    {:reply, info, state}
  end

  # --- Private ---

  defp maybe_adjust(state) do
    now = System.monotonic_time(:millisecond)

    if in_cooldown?(state, now) do
      state
    else
      med = median(state.window)
      do_adjust(state, med, now)
    end
  end

  defp in_cooldown?(%{last_adjustment_at: nil}, _now), do: false

  defp in_cooldown?(state, now) do
    now - state.last_adjustment_at < state.cooldown_ms
  end

  defp do_adjust(state, med, now)
       when med < state.up_threshold_ms and state.current_max < state.max_slots do
    new_max = state.current_max + 1
    Semaphore.set_max(new_max, state.semaphore)

    Logger.info("AI.Autoscaler: scaling UP #{state.current_max} -> #{new_max} (median: #{med}ms)")

    %{state | current_max: new_max, last_adjustment_at: now}
  end

  defp do_adjust(state, med, now)
       when med > state.down_threshold_ms and state.current_max > state.min_slots do
    new_max = state.current_max - 1
    Semaphore.set_max(new_max, state.semaphore)

    Logger.info(
      "AI.Autoscaler: scaling DOWN #{state.current_max} -> #{new_max} (median: #{med}ms)"
    )

    %{state | current_max: new_max, last_adjustment_at: now}
  end

  defp do_adjust(state, _med, _now), do: state

  defp median(list) do
    sorted = Enum.sort(list)
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) |> div(2)
    else
      Enum.at(sorted, mid)
    end
  end

  defp read_setting(name, default) do
    FeatureFlags.get_system_setting_value(name, default)
  rescue
    _ -> default
  end
end
