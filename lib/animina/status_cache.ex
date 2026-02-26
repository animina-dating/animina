defmodule Animina.StatusCache do
  @moduledoc """
  Centralized cache for /status page data.

  A single GenServer fetches all expensive data (HTTP pings, Prometheus metrics,
  DB aggregations) on fixed intervals and writes results to an ETS table.
  LiveViews read from ETS (microseconds) instead of making live HTTP/DB calls.

  Follows the MailQueueChecker pattern: GenServer + ETS with read_concurrency.
  """

  use GenServer

  require Logger

  alias Animina.Accounts
  alias Animina.AI.Queue
  alias Animina.Monitoring.PrometheusClient

  @table :status_cache

  @server_nodes_interval :timer.seconds(10)
  @user_stats_interval :timer.seconds(60)
  @charts_interval :timer.minutes(5)

  @time_frames [
    {"24h", 24, 10},
    {"48h", 48, 20},
    {"72h", 72, 30},
    {"7d", 168, 120},
    {"28d", 672, 360}
  ]

  # --- Public API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Returns the list of enriched server node maps."
  def server_nodes do
    lookup(:server_nodes, [])
  end

  @doc "Returns the user stats map (all the stat_* keys)."
  def user_stats do
    lookup(:user_stats, nil)
  end

  @doc "Returns cached online graph data for the given time frame key."
  def online_graph(frame) do
    lookup({:online_graph, frame}, [])
  end

  @doc "Returns cached registration graph data for the given time frame key."
  def registration_graph(frame) do
    lookup({:registration_graph, frame}, {[], []})
  end

  @doc "Returns the accumulated CPU load history map (%{host => [{t, pct}, ...]})."
  def load_history do
    lookup(:load_history, %{})
  end

  @doc "Returns the accumulated GPU load history map (%{host => %{uuid => [{t, pct}, ...]}})."
  def gpu_load_history do
    lookup(:gpu_load_history, %{})
  end

  # --- GenServer callbacks ---

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, @table)

    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    state = %{
      table_name: table_name,
      load_history: %{},
      gpu_load_history: %{},
      gpu_cache: %{}
    }

    # Run all refreshes immediately
    send(self(), :refresh_server_nodes)
    send(self(), :refresh_user_stats)
    send(self(), :refresh_charts)

    {:ok, state}
  end

  @impl true
  def handle_info(:refresh_server_nodes, state) do
    state = do_refresh_server_nodes(state)
    schedule(:refresh_server_nodes, @server_nodes_interval)
    {:noreply, state}
  end

  def handle_info(:refresh_user_stats, state) do
    do_refresh_user_stats(state.table_name)
    schedule(:refresh_user_stats, @user_stats_interval)
    {:noreply, state}
  end

  def handle_info(:refresh_charts, state) do
    do_refresh_charts(state.table_name)
    schedule(:refresh_charts, @charts_interval)
    {:noreply, state}
  end

  # --- Private: Server Nodes ---

  defp do_refresh_server_nodes(state) do
    instances =
      try do
        Queue.status()
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end

    # Ping all instances in parallel
    pings =
      instances
      |> Task.async_stream(&ping_instance/1, timeout: 6_000, on_timeout: :kill_task)
      |> Enum.map(fn
        {:ok, result} -> result
        _ -> nil
      end)

    instances_with_pings = Enum.zip(instances, pings)

    # Group instances by host
    {hosts_ordered, by_host} =
      Enum.reduce(instances_with_pings, {[], %{}}, fn {inst, ping_ms}, {hosts, map} ->
        host = extract_host(inst.url)
        entry = %{online?: ping_ms != nil, ping_ms: ping_ms, tags: inst.tags, busy: inst.busy}

        if Map.has_key?(map, host) do
          {hosts, Map.update!(map, host, &[entry | &1])}
        else
          {[host | hosts], Map.put(map, host, [entry])}
        end
      end)

    hosts_ordered = Enum.reverse(hosts_ordered)

    # Fetch node + GPU metrics in parallel
    all_tasks = Enum.flat_map(hosts_ordered, &spawn_metric_tasks(&1, by_host))
    results = Enum.map(all_tasks, &yield_metric_task/1)

    node_metrics_map =
      results
      |> Enum.filter(fn {type, _, _} -> type == :node end)
      |> Map.new(fn {_, host, metrics} -> {host, metrics} end)

    # Merge GPU results into cache
    gpu_cache =
      results
      |> Enum.filter(fn {type, _, _} -> type == :gpu end)
      |> Enum.reduce(state.gpu_cache, fn {_, host, gpus}, cache ->
        if gpus != [], do: Map.put(cache, host, gpus), else: cache
      end)

    # Accumulate CPU load history per host
    now = System.monotonic_time(:second)

    load_history =
      Enum.reduce(hosts_ordered, state.load_history, fn host, hist ->
        case node_metrics_map do
          %{^host => %{load_pct: pct}} when is_number(pct) ->
            prev = Map.get(hist, host, [])
            Map.put(hist, host, Enum.take([{now, pct} | prev], 720))

          _ ->
            hist
        end
      end)

    # Accumulate GPU load history per host per GPU UUID
    gpu_load_history =
      Enum.reduce(hosts_ordered, state.gpu_load_history, fn host, hist ->
        gpus = Map.get(gpu_cache, host, [])
        host_hist = Map.get(hist, host, %{})
        Map.put(hist, host, accumulate_gpu_history(gpus, host_hist, now))
      end)

    # Build enriched node list
    {nodes, _counter} =
      Enum.reduce(hosts_ordered, {[], 1}, fn host, {acc, counter} ->
        ollama_instances = Enum.reverse(Map.get(by_host, host, []))
        {name, next_counter} = {"ANIMINA Server #{counter}", counter + 1}
        has_gpu? = Enum.any?(ollama_instances, &("gpu" in &1.tags))

        node = %{
          name: name,
          has_gpu?: has_gpu?,
          ollama_instances: ollama_instances,
          node_metrics: Map.get(node_metrics_map, host),
          gpu_metrics: Map.get(gpu_cache, host, []),
          load_history: Map.get(load_history, host, []),
          gpu_load_history: Map.get(gpu_load_history, host, %{})
        }

        {[node | acc], next_counter}
      end)

    :ets.insert(state.table_name, {:server_nodes, Enum.reverse(nodes)})
    :ets.insert(state.table_name, {:load_history, load_history})
    :ets.insert(state.table_name, {:gpu_load_history, gpu_load_history})

    %{
      state
      | load_history: load_history,
        gpu_load_history: gpu_load_history,
        gpu_cache: gpu_cache
    }
  end

  defp ping_instance(stat) do
    base_url = stat.url |> String.replace(~r{/api/?$}, "")

    start = System.monotonic_time(:millisecond)

    case Req.get(base_url, receive_timeout: 5_000, connect_options: [timeout: 5_000]) do
      {:ok, %{status: 200}} ->
        System.monotonic_time(:millisecond) - start

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp extract_host(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end

  defp spawn_metric_tasks(host, by_host) do
    node_task = {:node, host, Task.async(fn -> PrometheusClient.fetch_node_metrics(host) end)}
    has_gpu? = by_host |> Map.get(host, []) |> Enum.any?(&("gpu" in &1.tags))

    if has_gpu?,
      do: [
        node_task,
        {:gpu, host, Task.async(fn -> PrometheusClient.fetch_gpu_metrics(host) end)}
      ],
      else: [node_task]
  end

  defp yield_metric_task({type, host, task}) do
    case Task.yield(task, 8_000) || Task.shutdown(task) do
      {:ok, result} -> {type, host, result}
      _ when type == :gpu -> {:gpu, host, []}
      _ -> {:node, host, nil}
    end
  end

  defp accumulate_gpu_history(gpus, host_hist, now) do
    Enum.reduce(gpus, host_hist, fn gpu, h ->
      if is_binary(gpu.uuid) and is_number(gpu.utilization_pct) do
        prev = Map.get(h, gpu.uuid, [])
        Map.put(h, gpu.uuid, Enum.take([{now, gpu.utilization_pct} | prev], 720))
      else
        h
      end
    end)
  end

  # --- Private: User Stats ---

  defp do_refresh_user_stats(table_name) do
    by_state = Accounts.count_confirmed_users_by_state()
    by_gender = Accounts.count_confirmed_users_by_gender()

    stats = %{
      stat_total_users: Accounts.count_active_users(),
      stat_confirmed: Accounts.count_confirmed_users(),
      stat_unconfirmed: Accounts.count_unconfirmed_users(),
      stat_online_now: AniminaWeb.Presence.online_user_count(),
      stat_today_berlin: Accounts.count_confirmed_users_today_berlin(),
      stat_yesterday: Accounts.count_confirmed_users_yesterday_berlin(),
      stat_last_7_days: Accounts.count_confirmed_users_last_7_days(),
      stat_last_28_days: Accounts.count_confirmed_users_last_28_days(),
      stat_30_day_avg: format_avg(Accounts.average_daily_confirmed_users_last_30_days()),
      stat_normal: Map.get(by_state, "normal", 0),
      stat_waitlisted: Map.get(by_state, "waitlisted", 0),
      stat_male: Map.get(by_gender, "male", 0),
      stat_female: Map.get(by_gender, "female", 0),
      stat_diverse: Map.get(by_gender, "diverse", 0)
    }

    :ets.insert(table_name, {:user_stats, stats})
  rescue
    e ->
      Logger.warning("StatusCache: user stats refresh failed: #{inspect(e)}")
  end

  defp format_avg(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  defp format_avg(_), do: "0.0"

  # --- Private: Charts ---

  defp do_refresh_charts(table_name) do
    for {frame, hours, bucket_minutes} <- @time_frames do
      since = DateTime.utc_now() |> DateTime.add(-hours, :hour)

      online_data = Accounts.online_user_counts_since(since, bucket_minutes)
      :ets.insert(table_name, {{:online_graph, frame}, online_data})

      reg_data = Accounts.registration_counts_since(since, bucket_minutes)
      confirm_data = Accounts.confirmation_counts_since(since, bucket_minutes)
      :ets.insert(table_name, {{:registration_graph, frame}, {reg_data, confirm_data}})
    end
  rescue
    e ->
      Logger.warning("StatusCache: charts refresh failed: #{inspect(e)}")
  end

  # --- Helpers ---

  defp lookup(key, default) do
    case :ets.lookup(@table, key) do
      [{_, value}] -> value
      [] -> default
    end
  rescue
    ArgumentError -> default
  end

  defp schedule(message, interval) do
    Process.send_after(self(), message, interval)
  end
end
