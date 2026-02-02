defmodule Animina.Accounts.OnlineUsersLogger do
  @moduledoc """
  A GenServer that periodically logs the online user count to the database.
  Records a snapshot every 2 minutes.
  """
  use GenServer

  alias Animina.Accounts
  alias AniminaWeb.Presence

  @interval :timer.minutes(2)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_log()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:log_count, state) do
    count = Presence.online_user_count()
    Accounts.record_online_user_count(count)
    schedule_log()
    {:noreply, state}
  end

  defp schedule_log do
    Process.send_after(self(), :log_count, @interval)
  end
end
