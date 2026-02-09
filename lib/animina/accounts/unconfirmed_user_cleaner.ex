defmodule Animina.Accounts.UnconfirmedUserCleaner do
  @moduledoc """
  A GenServer that periodically deletes unconfirmed users
  whose confirmation PIN has expired (duration configured via
  the `pin_validity_minutes` feature flag).
  """
  use GenServer

  alias Animina.Accounts

  @interval :timer.seconds(60)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Accounts.delete_expired_unconfirmed_users()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @interval)
  end
end
