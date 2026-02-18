defmodule Animina.AI.Semaphore do
  @moduledoc """
  Bounded concurrency semaphore for AI requests.

  Limits the number of concurrent Ollama API calls to prevent overwhelming
  the AI server. Callers acquire a slot before making a request and
  release it when done. Supports dynamic max adjustment via the admin panel.
  """

  use GenServer
  require Logger

  alias Animina.AI.Client

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Acquires a semaphore slot. Blocks until a slot is available or timeout expires.
  Returns `:ok` on success, `{:error, :timeout}` on timeout.
  """
  def acquire(timeout \\ 30_000, server \\ __MODULE__) do
    GenServer.call(server, {:acquire, timeout}, timeout + 5_000)
  end

  @doc """
  Releases a semaphore slot, allowing the next waiter to proceed.
  """
  def release(server \\ __MODULE__) do
    GenServer.cast(server, :release)
  end

  @doc """
  Returns current semaphore status for monitoring.
  Returns `%{active: N, max: M, waiting: K}`.
  """
  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  @doc """
  Dynamically updates the maximum concurrent slots.
  Can be used to manually adjust concurrency.
  """
  def set_max(new_max, server \\ __MODULE__) do
    GenServer.call(server, {:set_max, new_max})
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    max = Keyword.get(opts, :max, read_max_concurrent())

    state = %{
      max: max,
      active: 0,
      waiting: :queue.new()
    }

    Logger.info("AI.Semaphore started with max_concurrent=#{max}")
    {:ok, state}
  end

  @impl true
  def handle_call({:acquire, timeout}, from, state) do
    if state.active < state.max do
      {:reply, :ok, %{state | active: state.active + 1}}
    else
      timer_ref = Process.send_after(self(), {:timeout, from}, timeout)
      {pid, _tag} = from
      monitor_ref = Process.monitor(pid)

      waiter = %{from: from, timer_ref: timer_ref, monitor_ref: monitor_ref}
      waiting = :queue.in(waiter, state.waiting)
      {:noreply, %{state | waiting: waiting}}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      active: state.active,
      max: state.max,
      waiting: :queue.len(state.waiting)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:set_max, new_max}, _from, state) do
    old_max = state.max
    state = %{state | max: new_max}

    # If we increased max and have waiters, grant slots
    state = maybe_grant_waiting(state)

    Logger.info("AI.Semaphore max adjusted: #{old_max} -> #{new_max}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:release, state) do
    {:noreply, release_slot(state)}
  end

  @impl true
  def handle_info({:timeout, from}, state) do
    {waiter, new_waiting} = remove_waiter(state.waiting, from)

    if waiter do
      Process.demonitor(waiter.monitor_ref, [:flush])
      GenServer.reply(from, {:error, :timeout})
    end

    {:noreply, %{state | waiting: new_waiting}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_waiting =
      :queue.filter(
        fn waiter ->
          {waiter_pid, _tag} = waiter.from

          if waiter_pid == pid do
            Process.cancel_timer(waiter.timer_ref)
            false
          else
            true
          end
        end,
        state.waiting
      )

    {:noreply, %{state | waiting: new_waiting}}
  end

  # --- Private ---

  defp release_slot(state) do
    new_active = max(state.active - 1, 0)

    case grant_next_waiter(state.waiting) do
      {:granted, waiter, new_waiting} ->
        Process.cancel_timer(waiter.timer_ref)
        Process.demonitor(waiter.monitor_ref, [:flush])
        GenServer.reply(waiter.from, :ok)
        %{state | active: new_active + 1, waiting: new_waiting}

      :empty ->
        %{state | active: new_active}
    end
  end

  defp maybe_grant_waiting(state) do
    if state.active < state.max do
      case grant_next_waiter(state.waiting) do
        {:granted, waiter, new_waiting} ->
          Process.cancel_timer(waiter.timer_ref)
          Process.demonitor(waiter.monitor_ref, [:flush])
          GenServer.reply(waiter.from, :ok)
          maybe_grant_waiting(%{state | active: state.active + 1, waiting: new_waiting})

        :empty ->
          state
      end
    else
      state
    end
  end

  defp grant_next_waiter(waiting) do
    case :queue.out(waiting) do
      {{:value, waiter}, new_waiting} ->
        {:granted, waiter, new_waiting}

      {:empty, _} ->
        :empty
    end
  end

  defp remove_waiter(waiting, target_from) do
    {found, new_queue} =
      :queue.fold(
        fn waiter, {found, acc} ->
          if waiter.from == target_from do
            {waiter, acc}
          else
            {found, :queue.in(waiter, acc)}
          end
        end,
        {nil, :queue.new()},
        waiting
      )

    {found, new_queue}
  end

  defp read_max_concurrent do
    length(Client.ollama_instances())
  rescue
    _ -> 2
  end
end
