defmodule Animina.MailLogChecker do
  @moduledoc """
  Periodically tails `/var/log/mail.log` for Postfix bounce entries and
  broadcasts delivery failures via PubSub.

  Bounces are stored in an ETS table for fast lookups from LiveViews.
  Uses the same PubSub topic and message format as `MailQueueChecker`.
  """

  use GenServer

  require Logger

  alias Animina.ActivityLog
  alias Animina.Emails
  alias Animina.MailLogChecker.Parser
  alias Animina.MailQueueChecker

  @default_table :mail_log_bounces
  @default_interval :timer.seconds(10)
  @default_log_path "/var/log/mail.log"

  # --- Public API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Looks up a bounce entry for the given email address.
  Returns the entry map or nil.
  """
  def lookup(email, table_name \\ @default_table) do
    case :ets.lookup(table_name, String.downcase(email)) do
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
    log_path = Keyword.get(opts, :log_path, @default_log_path)
    read_fn = Keyword.get(opts, :read_fn, &default_read_fn/2)
    update_fn = Keyword.get(opts, :update_fn, &default_update_fn/2)

    table = :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    state = %{
      table_name: table,
      interval: interval,
      log_path: log_path,
      read_fn: read_fn,
      update_fn: update_fn,
      byte_position: 0,
      known_recipients: MapSet.new()
    }

    # Start at end of file so we only see new bounces
    state = initialize_position(state)

    send(self(), :check)

    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    state = check_for_bounces(state)
    schedule_check(state.interval)
    {:noreply, state}
  end

  # --- Private ---

  defp initialize_position(state) do
    case File.stat(state.log_path) do
      {:ok, %{size: size}} -> %{state | byte_position: size}
      {:error, _} -> state
    end
  end

  defp check_for_bounces(state) do
    case state.read_fn.(state.log_path, state.byte_position) do
      {:ok, content, new_position} ->
        entries = Parser.parse(content)
        process_entries(entries, state, new_position)

      {:error, :file_shrunk, new_position} ->
        # Log rotation detected — re-read from new position (0)
        case state.read_fn.(state.log_path, new_position) do
          {:ok, content, final_position} ->
            entries = Parser.parse(content)
            process_entries(entries, state, final_position)

          _ ->
            %{state | byte_position: new_position}
        end

      {:error, _reason} ->
        state
    end
  end

  defp process_entries(entries, state, new_position) do
    new_recipients =
      for entry <- entries, reduce: state.known_recipients do
        acc ->
          :ets.insert(state.table_name, {entry.recipient, entry})

          unless MapSet.member?(acc, entry.recipient) do
            state.update_fn.(entry, :broadcast)
          end

          MapSet.put(acc, entry.recipient)
      end

    %{state | byte_position: new_position, known_recipients: new_recipients}
  end

  defp default_read_fn(path, byte_position) do
    case File.stat(path) do
      {:ok, %{size: size}} when size < byte_position ->
        # File shrunk (log rotation)
        {:error, :file_shrunk, 0}

      {:ok, %{size: size}} when size == byte_position ->
        {:ok, "", byte_position}

      {:ok, %{size: size}} ->
        case File.open(path, [:read, :binary]) do
          {:ok, file} ->
            :file.position(file, byte_position)
            bytes_to_read = size - byte_position
            {:ok, content} = IO.binread(file, bytes_to_read)
            File.close(file)
            {:ok, content, size}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp default_update_fn(entry, :broadcast) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      MailQueueChecker.topic(entry.recipient),
      {:mail_delivery_failure, entry}
    )

    Emails.mark_as_bounced(entry.recipient, entry.reason)

    ActivityLog.log(
      "system",
      "email_bounced",
      "Email bounced for #{entry.recipient}: #{entry.reason}",
      metadata: %{
        "recipient" => entry.recipient,
        "queue_id" => entry.queue_id,
        "reason" => entry.reason
      }
    )

    Logger.warning("Mail bounce detected for #{entry.recipient}: #{entry.reason}")
  end

  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval)
  end
end
