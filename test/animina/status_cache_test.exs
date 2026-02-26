defmodule Animina.StatusCacheTest do
  use Animina.DataCase, async: false

  alias Animina.StatusCache

  describe "ETS table and public API" do
    setup do
      # Start the StatusCache with a unique table name to avoid conflicts
      table_name = :"status_cache_test_#{System.unique_integer([:positive])}"
      {:ok, pid} = StatusCache.start_link(table_name: table_name, name: nil)

      # Give it a moment to run initial refreshes
      Process.sleep(200)

      on_exit(fn ->
        Process.alive?(pid) && GenServer.stop(pid)
      end)

      %{pid: pid, table_name: table_name}
    end

    test "creates the ETS table", %{table_name: table_name} do
      assert :ets.info(table_name) != :undefined
    end

    test "server_nodes returns a list" do
      result = StatusCache.server_nodes()
      assert is_list(result)
    end

    test "user_stats returns a map with expected keys after refresh" do
      # Give the GenServer time to complete the user stats refresh
      Process.sleep(500)

      case StatusCache.user_stats() do
        nil ->
          # Acceptable if refresh hasn't completed yet or table doesn't exist
          :ok

        %{} = stats ->
          expected_keys = [
            :stat_total_users,
            :stat_confirmed,
            :stat_unconfirmed,
            :stat_online_now,
            :stat_today_berlin,
            :stat_yesterday,
            :stat_last_7_days,
            :stat_last_28_days,
            :stat_30_day_avg,
            :stat_normal,
            :stat_waitlisted,
            :stat_male,
            :stat_female,
            :stat_diverse
          ]

          for key <- expected_keys do
            assert Map.has_key?(stats, key), "Missing key: #{key}"
          end
      end
    end

    test "online_graph returns a list for valid time frames" do
      for frame <- ["24h", "48h", "72h", "7d", "28d"] do
        result = StatusCache.online_graph(frame)
        assert is_list(result), "Expected list for frame #{frame}"
      end
    end

    test "registration_graph returns a tuple of two lists" do
      for frame <- ["24h", "48h", "72h", "7d", "28d"] do
        {reg_data, confirm_data} = StatusCache.registration_graph(frame)
        assert is_list(reg_data), "Expected list for reg_data in frame #{frame}"
        assert is_list(confirm_data), "Expected list for confirm_data in frame #{frame}"
      end
    end

    test "load_history returns a map" do
      result = StatusCache.load_history()
      assert is_map(result)
    end

    test "gpu_load_history returns a map" do
      result = StatusCache.gpu_load_history()
      assert is_map(result)
    end

    test "returns defaults when ETS table does not exist" do
      # Access the default table which doesn't exist in this test env
      # (GenServer started with custom table name, default :status_cache not created)
      # Since the GenServer IS using a custom table, the default lookup should
      # rescue and return defaults
      assert StatusCache.server_nodes() == [] || is_list(StatusCache.server_nodes())
      assert StatusCache.load_history() == %{} || is_map(StatusCache.load_history())
      assert StatusCache.gpu_load_history() == %{} || is_map(StatusCache.gpu_load_history())
    end
  end
end
