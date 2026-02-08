defmodule Animina.MailQueueChecker do
  @moduledoc """
  Periodically checks the Postfix mail queue for stuck emails and
  broadcasts delivery failures via PubSub.

  Failures are stored in an ETS table for fast lookups from LiveViews.
  """

  use GenServer

  alias Animina.MailQueueChecker.Parser

  @default_table :mail_queue_failures
  @default_interval :timer.seconds(30)

  # --- Public API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the PubSub topic for delivery failures for a given email.
  """
  def topic(email), do: "mail_queue:delivery_failure:#{email}"

  @doc """
  Looks up a delivery failure for the given email address.
  Returns the entry map or nil. Does not call the GenServer.
  """
  def lookup(email, table_name \\ @default_table) do
    case :ets.lookup(table_name, email) do
      [{_, entry}] -> entry
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  # --- GenServer callbacks ---

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, @default_table)
    interval = Keyword.get(opts, :interval, @default_interval)
    cmd_fn = Keyword.get(opts, :cmd_fn, &System.cmd/2)

    table = :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    state = %{
      table_name: table,
      interval: interval,
      cmd_fn: cmd_fn,
      known_ids: MapSet.new()
    }

    # Run the first check immediately
    send(self(), :check)

    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    {output, _exit_code} = state.cmd_fn.("mailq", [])

    entries = Parser.parse(output)

    # Rebuild ETS
    :ets.delete_all_objects(state.table_name)

    new_ids =
      for entry <- entries, entry.recipient != nil, reduce: MapSet.new() do
        acc ->
          :ets.insert(state.table_name, {entry.recipient, entry})
          MapSet.put(acc, entry.queue_id)
      end

    # Broadcast only for newly detected failures
    new_failures = MapSet.difference(new_ids, state.known_ids)

    for entry <- entries,
        entry.recipient != nil,
        MapSet.member?(new_failures, entry.queue_id) do
      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        topic(entry.recipient),
        {:mail_delivery_failure, entry}
      )
    end

    schedule_check(state.interval)

    {:noreply, %{state | known_ids: new_ids}}
  end

  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval)
  end
end
