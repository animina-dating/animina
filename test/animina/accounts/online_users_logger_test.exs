defmodule Animina.Accounts.OnlineUsersLoggerTest do
  use Animina.DataCase, async: false

  alias Animina.Accounts.OnlineUsersLogger

  describe "OnlineUsersLogger" do
    test "logs online user count when receiving :log_count message" do
      {:ok, pid} = OnlineUsersLogger.start_link([])

      # Send the log message manually
      send(pid, :log_count)

      # Give it a moment to process
      Process.sleep(100)

      # Should have inserted a record with count 0 (no users tracked in test)
      since = DateTime.utc_now() |> DateTime.add(-1, :hour)
      results = Animina.Accounts.online_user_counts_since(since, 60)
      assert length(results) == 1
      [%{avg_count: count}] = results
      assert count == 0

      GenServer.stop(pid)
    end
  end
end
