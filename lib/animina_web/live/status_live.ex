defmodule AniminaWeb.StatusLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Scope
  alias Animina.AI.Queue
  alias Animina.Monitoring.PrometheusClient
  alias Ecto.Adapters.SQL

  @refresh_interval 5_000

  @chart_width 800
  @chart_height 300
  @padding_left 50
  @padding_right 20
  @padding_top 20
  @padding_bottom 40

  @time_frames [
    {"24h", 24, 10},
    {"48h", 48, 20},
    {"72h", 72, 30},
    {"7d", 168, 120},
    {"28d", 672, 360}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    socket =
      socket
      |> assign(page_title: "System Status")
      |> assign_metrics()
      |> assign_ollama_stats()
      |> assign_user_stats()
      |> assign_online_graph()
      |> assign_registration_graph()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply,
     socket
     |> assign_metrics()
     |> assign_ollama_stats()
     |> assign_user_stats()
     |> assign_online_graph()
     |> assign_registration_graph()}
  end

  @impl true
  def handle_event("set_time_frame", %{"frame" => frame}, socket) do
    if admin?(socket) do
      {:noreply,
       socket
       |> assign(:online_time_frame, frame)
       |> load_online_data()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_reg_time_frame", %{"frame" => frame}, socket) do
    if admin?(socket) do
      {:noreply,
       socket
       |> assign(:reg_time_frame, frame)
       |> load_registration_data()}
    else
      {:noreply, socket}
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp admin?(socket) do
    case socket.assigns[:current_scope] do
      %Scope{} = scope -> Scope.admin?(scope)
      _ -> false
    end
  end

  defp assign_online_graph(socket) do
    if admin?(socket) do
      socket
      |> assign(:online_time_frame, socket.assigns[:online_time_frame] || "24h")
      |> assign(:online_user_count, AniminaWeb.Presence.online_user_count())
      |> assign_chart_dimensions()
      |> load_online_data()
    else
      socket
      |> assign(:online_time_frame, nil)
      |> assign(:online_data, [])
      |> assign(:online_user_count, nil)
    end
  end

  defp assign_registration_graph(socket) do
    if admin?(socket) do
      socket
      |> assign(:reg_time_frame, socket.assigns[:reg_time_frame] || "7d")
      |> load_registration_data()
    else
      socket
      |> assign(:reg_time_frame, nil)
      |> assign(:reg_data, [])
      |> assign(:confirm_data, [])
    end
  end

  defp assign_chart_dimensions(socket) do
    assign(socket,
      chart_width: @chart_width,
      chart_height: @chart_height,
      padding_left: @padding_left,
      padding_right: @padding_right,
      padding_top: @padding_top,
      padding_bottom: @padding_bottom
    )
  end

  defp load_online_data(socket) do
    frame = socket.assigns.online_time_frame
    {_label, hours, bucket_minutes} = Enum.find(@time_frames, fn {l, _, _} -> l == frame end)
    since = DateTime.utc_now() |> DateTime.add(-hours, :hour)
    data = Accounts.online_user_counts_since(since, bucket_minutes)
    assign(socket, :online_data, data)
  end

  defp load_registration_data(socket) do
    frame = socket.assigns.reg_time_frame
    {_label, hours, bucket_minutes} = Enum.find(@time_frames, fn {l, _, _} -> l == frame end)
    since = DateTime.utc_now() |> DateTime.add(-hours, :hour)

    reg_data = Accounts.registration_counts_since(since, bucket_minutes)
    confirm_data = Accounts.confirmation_counts_since(since, bucket_minutes)

    socket
    |> assign(:reg_data, reg_data)
    |> assign(:confirm_data, confirm_data)
  end

  defp assign_metrics(socket) do
    assign(socket,
      elixir_version: System.version(),
      otp_version: List.to_string(:erlang.system_info(:otp_release)),
      app_version: Animina.version(),
      db_status: check_database(),
      beam_memory: beam_memory(),
      system_memory: system_memory(),
      load_averages: load_averages(),
      process_count: :erlang.system_info(:process_count),
      scheduler_count: :erlang.system_info(:schedulers_online),
      cpu_info: cpu_info(),
      deployed_at: format_deployed_at(),
      uptime: format_uptime()
    )
  end

  defp assign_ollama_stats(socket) do
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

    # Group instances by host and assign names
    instances_with_pings = Enum.zip(instances, pings)

    # Collect unique hosts (preserving order) and group instances by host
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

    # Fetch node metrics for all hosts, GPU metrics only for hosts with gpu-tagged Ollama instances
    all_tasks = Enum.flat_map(hosts_ordered, &spawn_metric_tasks(&1, by_host))

    results = Enum.map(all_tasks, &yield_metric_task/1)

    node_metrics_map =
      results
      |> Enum.filter(fn {type, _, _} -> type == :node end)
      |> Map.new(fn {_, host, metrics} -> {host, metrics} end)

    # Merge fresh GPU results into cache — only update when new data arrived
    prev_gpu_cache = Map.get(socket.assigns, :gpu_cache, %{})

    gpu_cache =
      results
      |> Enum.filter(fn {type, _, _} -> type == :gpu end)
      |> Enum.reduce(prev_gpu_cache, fn {_, host, gpus}, cache ->
        if gpus != [], do: Map.put(cache, host, gpus), else: cache
      end)

    # Build enriched node list
    {nodes, _counter} =
      Enum.reduce(hosts_ordered, {[], 1}, fn host, {acc, counter} ->
        ollama_instances = Enum.reverse(Map.get(by_host, host, []))

        {name, next_counter} =
          if localhost_host?(host),
            do: {"This Server", counter},
            else: {"ANIMINA Server #{counter}", counter + 1}

        has_gpu? = Enum.any?(ollama_instances, &("gpu" in &1.tags))

        node = %{
          name: name,
          has_gpu?: has_gpu?,
          ollama_instances: ollama_instances,
          node_metrics: Map.get(node_metrics_map, host),
          gpu_metrics: Map.get(gpu_cache, host, [])
        }

        {[node | acc], next_counter}
      end)

    socket
    |> assign(:gpu_cache, gpu_cache)
    |> assign(:server_nodes, Enum.reverse(nodes))
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
    # Yield timeout must exceed @http_timeout (4s) to avoid killing in-flight requests
    case Task.yield(task, 8_000) || Task.shutdown(task) do
      {:ok, result} -> {type, host, result}
      _ when type == :gpu -> {:gpu, host, []}
      _ -> {:node, host, nil}
    end
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

  defp localhost_host?(host) do
    host in ["localhost", "127.0.0.1"]
  end

  defp assign_user_stats(socket) do
    if admin?(socket) do
      by_state = Accounts.count_confirmed_users_by_state()
      by_gender = Accounts.count_confirmed_users_by_gender()

      assign(socket,
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
      )
    else
      assign(socket,
        stat_total_users: nil,
        stat_confirmed: nil,
        stat_unconfirmed: nil,
        stat_online_now: nil,
        stat_today_berlin: nil,
        stat_yesterday: nil,
        stat_last_7_days: nil,
        stat_last_28_days: nil,
        stat_30_day_avg: nil,
        stat_normal: nil,
        stat_waitlisted: nil,
        stat_male: nil,
        stat_female: nil,
        stat_diverse: nil
      )
    end
  end

  defp format_avg(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  defp format_avg(_), do: "0.0"

  defp check_database do
    case SQL.query(Animina.Repo, "SELECT 1") do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  rescue
    _ -> :error
  end

  defp beam_memory do
    memory = :erlang.memory()

    %{
      total: format_bytes(memory[:total]),
      processes: format_bytes(memory[:processes]),
      ets: format_bytes(memory[:ets]),
      atoms: format_bytes(memory[:atom]),
      binaries: format_bytes(memory[:binary])
    }
  end

  defp system_memory do
    case :os.type() do
      {:unix, :linux} ->
        read_proc_meminfo()

      _ ->
        :not_available
    end
  end

  defp read_proc_meminfo do
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        values =
          Regex.scan(~r/^(MemTotal|MemAvailable):\s+(\d+)\s+kB/m, content)
          |> Enum.into(%{}, fn [_, key, val] -> {key, String.to_integer(val) * 1024} end)

        total = values["MemTotal"]
        available = values["MemAvailable"]

        if total && available do
          %{
            total: format_bytes(total),
            available: format_bytes(available),
            used: format_bytes(total - available)
          }
        else
          :not_available
        end

      {:error, _} ->
        :not_available
    end
  end

  defp load_averages do
    case :os.type() do
      {:unix, :linux} ->
        read_proc_loadavg()

      {:unix, :darwin} ->
        read_sysctl_loadavg()

      _ ->
        :not_available
    end
  end

  defp read_proc_loadavg do
    case File.read("/proc/loadavg") do
      {:ok, content} ->
        case String.split(content) do
          [l1, l5, l15 | _] -> {l1, l5, l15}
          _ -> :not_available
        end

      {:error, _} ->
        :not_available
    end
  end

  defp read_sysctl_loadavg do
    case System.cmd("sysctl", ["-n", "vm.loadavg"], stderr_to_stdout: true) do
      {output, 0} ->
        output = String.trim(output) |> String.trim_leading("{ ") |> String.trim_trailing(" }")

        case String.split(output) do
          [l1, l5, l15 | _] -> {l1, l5, l15}
          _ -> :not_available
        end

      _ ->
        :not_available
    end
  end

  defp cpu_info do
    case :os.type() do
      {:unix, :linux} -> cpu_info_linux()
      {:unix, :darwin} -> cpu_info_darwin()
      _ -> :not_available
    end
  end

  defp cpu_info_linux do
    case File.read("/proc/cpuinfo") do
      {:ok, content} ->
        model =
          case Regex.run(~r/^model name\s*:\s*(.+)$/m, content) do
            [_, name] -> String.trim(name)
            _ -> "Unknown"
          end

        count =
          Regex.scan(~r/^processor\s*:/m, content)
          |> length()

        %{model: model, count: count}

      {:error, _} ->
        :not_available
    end
  end

  defp cpu_info_darwin do
    with {model, 0} <-
           System.cmd("sysctl", ["-n", "machdep.cpu.brand_string"], stderr_to_stdout: true),
         {count_str, 0} <- System.cmd("sysctl", ["-n", "hw.ncpu"], stderr_to_stdout: true) do
      %{model: String.trim(model), count: String.trim(count_str) |> String.to_integer()}
    else
      _ -> :not_available
    end
  end

  defp format_deployed_at do
    Animina.deployed_at()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> Calendar.strftime("%d.%m.%Y %H:%M:%S %Z")
  end

  defp format_uptime do
    diff = DateTime.diff(DateTime.utc_now(), Animina.deployed_at(), :second)
    days = div(diff, 86_400)
    hours = div(rem(diff, 86_400), 3_600)
    minutes = div(rem(diff, 3_600), 60)

    parts =
      [{days, "d"}, {hours, "h"}, {minutes, "m"}]
      |> Enum.filter(fn {val, _} -> val > 0 end)
      |> Enum.map(fn {val, unit} -> "#{val}#{unit}" end)

    case parts do
      [] -> "< 1m"
      _ -> Enum.join(parts, " ")
    end
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  # SVG chart helpers

  defp chart_points(data, max_count) when length(data) < 2 or max_count < 1, do: ""

  defp chart_points(data, max_count) do
    plot_w = @chart_width - @padding_left - @padding_right
    plot_h = @chart_height - @padding_top - @padding_bottom
    n = length(data)

    data
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {%{avg_count: count}, i} ->
      x = @padding_left + i * plot_w / max(n - 1, 1)
      y = @padding_top + plot_h - count / max_count * plot_h
      "#{Float.round(x, 1)},#{Float.round(y, 1)}"
    end)
  end

  defp y_axis_labels_for_max(max_count) do
    plot_h = @chart_height - @padding_top - @padding_bottom
    steps = 4

    for i <- 0..steps do
      val = round(max_count * i / steps)
      y = @padding_top + plot_h - i / steps * plot_h
      {Integer.to_string(val), Float.round(y, 1)}
    end
  end

  defp x_axis_labels([], _time_frame), do: []

  defp x_axis_labels(data, time_frame) do
    plot_w = @chart_width - @padding_left - @padding_right
    n = length(data)
    label_count = min(n, 6)
    step = max(div(n - 1, label_count), 1)
    use_date? = time_frame in ["7d", "28d"]

    data
    |> Enum.with_index()
    |> Enum.filter(fn {_, i} -> rem(i, step) == 0 end)
    |> Enum.map(fn {%{bucket: bucket}, i} ->
      x = @padding_left + i * plot_w / max(n - 1, 1)
      berlin = DateTime.shift_zone!(bucket, "Europe/Berlin", Tz.TimeZoneDatabase)

      label =
        if use_date?,
          do: Calendar.strftime(berlin, "%d.%m %H:%M"),
          else: Calendar.strftime(berlin, "%H:%M")

      {label, Float.round(x, 1)}
    end)
  end

  defp grid_y_positions([]), do: []

  defp grid_y_positions(_data) do
    plot_h = @chart_height - @padding_top - @padding_bottom
    steps = 4

    for i <- 1..steps do
      Float.round(@padding_top + plot_h - i / steps * plot_h, 1)
    end
  end

  defp chart_point_circles(data, max_count) when length(data) < 2 or max_count < 1, do: []

  defp chart_point_circles(data, max_count) do
    plot_w = @chart_width - @padding_left - @padding_right
    plot_h = @chart_height - @padding_top - @padding_bottom
    n = length(data)

    if n <= 50 do
      data
      |> Enum.with_index()
      |> Enum.map(fn {%{avg_count: count}, i} ->
        x = @padding_left + i * plot_w / max(n - 1, 1)
        y = @padding_top + plot_h - count / max_count * plot_h
        %{x: Float.round(x, 1), y: Float.round(y, 1)}
      end)
    else
      []
    end
  end

  defp max_count_for(data) do
    case data do
      [] -> 1
      _ -> data |> Enum.map(& &1.avg_count) |> Enum.max() |> max(1)
    end
  end

  defp time_frame_options do
    [
      {"24h", "24 hours"},
      {"48h", "48 hours"},
      {"72h", "72 hours"},
      {"7d", "7 days"},
      {"28d", "28 days"}
    ]
  end

  # Reusable chart function component

  attr :data, :list, required: true
  attr :data2, :list, default: nil
  attr :time_frame, :string, required: true
  attr :color, :string, default: "#2563eb"
  attr :color2, :string, default: nil

  defp chart(assigns) do
    primary_max = max_count_for(assigns.data)

    secondary_max =
      if assigns.data2, do: max_count_for(assigns.data2), else: 0

    max_count = max(primary_max, secondary_max)
    x_data = if assigns.data != [], do: assigns.data, else: assigns.data2 || []

    assigns =
      assigns
      |> assign(:max_count, max_count)
      |> assign(:x_data, x_data)
      |> assign(:chart_width, @chart_width)
      |> assign(:chart_height, @chart_height)
      |> assign(:padding_left, @padding_left)
      |> assign(:padding_right, @padding_right)
      |> assign(:padding_top, @padding_top)
      |> assign(:padding_bottom, @padding_bottom)

    ~H"""
    <svg
      viewBox={"0 0 #{@chart_width} #{@chart_height}"}
      class="w-full h-auto"
      preserveAspectRatio="xMidYMid meet"
    >
      <%!-- Grid lines --%>
      <%= for y <- grid_y_positions(@data) do %>
        <line
          x1={@padding_left}
          y1={y}
          x2={@chart_width - @padding_right}
          y2={y}
          stroke="#e5e7eb"
          stroke-dasharray="4,4"
        />
      <% end %>
      <%!-- Y axis labels --%>
      <%= for {label, y} <- y_axis_labels_for_max(@max_count) do %>
        <text
          x={@padding_left - 8}
          y={y + 4}
          text-anchor="end"
          class="fill-gray-400"
          font-size="11"
          font-family="monospace"
        >
          {label}
        </text>
      <% end %>
      <%!-- X axis labels --%>
      <%= for {label, x} <- x_axis_labels(@x_data, @time_frame) do %>
        <text
          x={x}
          y={@chart_height - 8}
          text-anchor="middle"
          class="fill-gray-400"
          font-size="10"
          font-family="monospace"
        >
          {label}
        </text>
      <% end %>
      <%!-- Axes --%>
      <line
        x1={@padding_left}
        y1={@padding_top}
        x2={@padding_left}
        y2={@chart_height - @padding_bottom}
        stroke="#9ca3af"
        stroke-width="1"
      />
      <line
        x1={@padding_left}
        y1={@chart_height - @padding_bottom}
        x2={@chart_width - @padding_right}
        y2={@chart_height - @padding_bottom}
        stroke="#9ca3af"
        stroke-width="1"
      />
      <%!-- Primary data line --%>
      <polyline
        points={chart_points(@data, @max_count)}
        fill="none"
        stroke={@color}
        stroke-width="2"
        stroke-linejoin="round"
      />
      <%= for point <- chart_point_circles(@data, @max_count) do %>
        <circle cx={point.x} cy={point.y} r="3" fill={@color} />
      <% end %>
      <%!-- Secondary data line --%>
      <%= if @data2 do %>
        <polyline
          points={chart_points(@data2, @max_count)}
          fill="none"
          stroke={@color2}
          stroke-width="2"
          stroke-linejoin="round"
        />
        <%= for point <- chart_point_circles(@data2, @max_count) do %>
          <circle cx={point.x} cy={point.y} r="3" fill={@color2} />
        <% end %>
      <% end %>
    </svg>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <h1 class="text-2xl font-bold mb-8">System Status</h1>

        <%!-- Server Nodes --%>
        <h2 class="text-lg font-semibold mb-4">Server Nodes</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <%= for node <- @server_nodes do %>
            <.server_node_card node={node} />
          <% end %>
        </div>

        <%= if @current_scope && Scope.admin?(@current_scope) do %>
          <div class="grid grid-cols-3 gap-6 mb-8">
            <.section title="User Totals">
              <.row label="Total Users" value={@stat_total_users} />
              <.row label="Confirmed" value={@stat_confirmed} />
              <.row label="Unconfirmed" value={@stat_unconfirmed} />
              <.row label="Online Now" value={@stat_online_now} />
            </.section>

            <.section title="Growth (Confirmed)">
              <.row label="Today (Berlin)" value={@stat_today_berlin} />
              <.row label="Yesterday" value={@stat_yesterday} />
              <.row label="Last 7 Days" value={@stat_last_7_days} />
              <.row label="Last 28 Days" value={@stat_last_28_days} />
              <.row label="30-Day Avg" value={@stat_30_day_avg} />
            </.section>

            <.section title="Breakdown (Confirmed)">
              <.row label="Normal" value={@stat_normal} />
              <.row label="Waitlisted" value={@stat_waitlisted} />
              <.row label="Male" value={@stat_male} />
              <.row label="Female" value={@stat_female} />
              <.row label="Diverse" value={@stat_diverse} />
            </.section>
          </div>

          <div class="mb-8 bg-white rounded-lg border border-gray-200 overflow-hidden">
            <div class="bg-gray-50 px-4 py-3 border-b border-gray-200 flex items-center justify-between">
              <h2 class="text-sm font-semibold text-gray-700">
                Online Users
                <span class="ml-2 text-xs font-normal text-gray-500">
                  (currently {@online_user_count})
                </span>
              </h2>
              <div class="flex gap-1">
                <%= for {key, label} <- time_frame_options() do %>
                  <button
                    phx-click="set_time_frame"
                    phx-value-frame={key}
                    class={[
                      "px-2.5 py-1 text-xs font-medium rounded",
                      if(@online_time_frame == key,
                        do: "bg-blue-600 text-white",
                        else: "bg-gray-100 text-gray-600 hover:bg-gray-200"
                      )
                    ]}
                  >
                    {label}
                  </button>
                <% end %>
              </div>
            </div>
            <div class="p-4">
              <%= if @online_data == [] do %>
                <p class="text-sm text-gray-400 text-center py-8">
                  No data yet. Data is recorded every 2 minutes.
                </p>
              <% else %>
                <.chart data={@online_data} time_frame={@online_time_frame} color="#2563eb" />
              <% end %>
            </div>
          </div>

          <div class="mb-8 bg-white rounded-lg border border-gray-200 overflow-hidden">
            <div class="bg-gray-50 px-4 py-3 border-b border-gray-200 flex items-center justify-between">
              <h2 class="text-sm font-semibold text-gray-700">New Registrations</h2>
              <div class="flex gap-1">
                <%= for {key, label} <- time_frame_options() do %>
                  <button
                    phx-click="set_reg_time_frame"
                    phx-value-frame={key}
                    class={[
                      "px-2.5 py-1 text-xs font-medium rounded",
                      if(@reg_time_frame == key,
                        do: "bg-blue-600 text-white",
                        else: "bg-gray-100 text-gray-600 hover:bg-gray-200"
                      )
                    ]}
                  >
                    {label}
                  </button>
                <% end %>
              </div>
            </div>
            <div class="p-4">
              <div class="flex gap-4 mb-2 text-xs text-gray-700">
                <span class="flex items-center gap-1">
                  <span class="inline-block w-3 h-0.5 bg-[#16a34a]"></span> Registered
                </span>
                <span class="flex items-center gap-1">
                  <span class="inline-block w-3 h-0.5 bg-[#2563eb]"></span> Confirmed
                </span>
              </div>
              <%= if @reg_data == [] && @confirm_data == [] do %>
                <p class="text-sm text-gray-400 text-center py-8">
                  No registration data for this period.
                </p>
              <% else %>
                <.chart
                  data={@reg_data}
                  data2={@confirm_data}
                  time_frame={@reg_time_frame}
                  color="#16a34a"
                  color2="#2563eb"
                />
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- This Server --%>
        <h2 class="text-lg font-semibold mb-4">This Server</h2>
        <div class="grid grid-cols-2 gap-6 mb-8">
          <.section title="Deployment">
            <.row label="Deployed At" value={@deployed_at} />
            <.row label="Uptime" value={@uptime} />
          </.section>

          <.section title="Versions">
            <.row label="ANIMINA" value={@app_version} />
            <.row label="Elixir" value={@elixir_version} />
            <.row label="Erlang/OTP" value={@otp_version} />
          </.section>

          <.section title="System Load">
            <%= if @load_averages == :not_available do %>
              <.row label="Status" value="N/A" />
            <% else %>
              <.row label="1 min" value={elem(@load_averages, 0)} />
              <.row label="5 min" value={elem(@load_averages, 1)} />
              <.row label="15 min" value={elem(@load_averages, 2)} />
            <% end %>
          </.section>

          <.section title="BEAM Memory">
            <.row label="Total" value={@beam_memory.total} />
            <.row label="Processes" value={@beam_memory.processes} />
            <.row label="ETS" value={@beam_memory.ets} />
            <.row label="Atoms" value={@beam_memory.atoms} />
            <.row label="Binaries" value={@beam_memory.binaries} />
          </.section>

          <.section title="System Memory">
            <%= if @system_memory == :not_available do %>
              <.row label="Status" value="N/A (not Linux)" />
            <% else %>
              <.row label="Total" value={@system_memory.total} />
              <.row label="Available" value={@system_memory.available} />
              <.row label="Used" value={@system_memory.used} />
            <% end %>
          </.section>

          <.section title="Database">
            <.row label="PostgreSQL">
              <span class={[
                "inline-flex items-center gap-1 font-medium",
                @db_status == :ok && "text-green-800",
                @db_status == :error && "text-red-800"
              ]}>
                {if @db_status == :ok, do: "● Connected", else: "● Unreachable"}
              </span>
            </.row>
          </.section>

          <.section title="BEAM / CPU Info">
            <%= if @cpu_info != :not_available do %>
              <.row label="CPU Model" value={@cpu_info.model} />
              <.row label="CPU Cores" value={@cpu_info.count} />
            <% else %>
              <.row label="CPU Model" value="N/A" />
              <.row label="CPU Cores" value="N/A" />
            <% end %>
            <.row label="Schedulers" value={@scheduler_count} />
            <.row label="Process Count" value={@process_count} />
          </.section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :node, :map, required: true

  defp server_node_card(assigns) do
    any_online? = Enum.any?(assigns.node.ollama_instances, & &1.online?)

    assigns =
      assigns
      |> assign(:any_online?, any_online?)
      |> assign(:m, assigns.node.node_metrics)

    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <%!-- Header --%>
      <div class="bg-gray-50 px-4 py-3 border-b border-gray-200 flex items-center justify-between">
        <h3 class="text-sm font-semibold text-gray-700">{@node.name}</h3>
        <span class={[
          "inline-flex items-center gap-1 text-xs font-medium",
          @any_online? && "text-green-700",
          !@any_online? && "text-red-700"
        ]}>
          <span class={[
            "inline-block w-2 h-2 rounded-full",
            @any_online? && "bg-green-500",
            !@any_online? && "bg-red-500"
          ]}>
          </span>
          {if @any_online?, do: "Online", else: "Offline"}
        </span>
      </div>

      <div class="p-4 space-y-4">
        <%!-- Hardware Metrics --%>
        <%= if @m do %>
          <%!-- CPU Info --%>
          <div class="text-xs text-gray-500">
            <%= if @m.cpu_model do %>
              <div class="truncate" title={@m.cpu_model}>
                {short_cpu_name(@m.cpu_model)}
                <%= if @m.cpu_count do %>
                  <span class="text-gray-400">({@m.cpu_count} cores)</span>
                <% end %>
              </div>
            <% else %>
              <span class="font-medium text-gray-600">{@m.cpu_count || "?"} cores</span>
              <%= if @m.cpu_max_freq_hz do %>
                <span>@ {format_freq(@m.cpu_max_freq_hz)}</span>
              <% end %>
            <% end %>
          </div>

          <%!-- CPU / Load --%>
          <div>
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-medium text-gray-600">
                CPU Load
              </span>
              <span class="text-xs font-mono text-gray-500">
                {@m.load1} / {@m.load5} / {@m.load15}
              </span>
            </div>
            <%= if @m.load_pct do %>
              <.usage_bar pct={@m.load_pct} />
            <% end %>
          </div>

          <%!-- RAM --%>
          <div>
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-medium text-gray-600">RAM</span>
              <span class="text-xs font-mono text-gray-500">
                {format_bytes_short(@m.memory_used_bytes)} / {format_bytes_short(
                  @m.memory_total_bytes
                )}
              </span>
            </div>
            <.usage_bar pct={@m.memory_used_pct} />
          </div>
        <% else %>
          <div class="text-xs text-gray-400 italic">Hardware metrics unavailable</div>
        <% end %>

        <%!-- GPU Metrics --%>
        <%= if @node.has_gpu? && @node.gpu_metrics == [] do %>
          <div class="border-t border-gray-100 pt-3 flex items-center gap-2 text-xs text-gray-400">
            <svg class="animate-spin h-3.5 w-3.5" viewBox="0 0 24 24" fill="none">
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              />
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
            Loading GPU metrics…
          </div>
        <% end %>
        <%= if @node.gpu_metrics != [] do %>
          <%= for gpu <- @node.gpu_metrics do %>
            <div class="border-t border-gray-100 pt-3">
              <div class="text-xs text-gray-500 truncate mb-2" title={gpu.name}>
                {short_gpu_name(gpu.name)}
              </div>

              <%= if gpu.utilization_pct do %>
                <div>
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-xs font-medium text-gray-600">GPU Load</span>
                    <span class="text-xs font-mono text-gray-500">
                      {gpu.utilization_pct}%
                    </span>
                  </div>
                  <.usage_bar pct={gpu.utilization_pct} />
                </div>
              <% end %>

              <%= if gpu.memory_total_bytes && gpu.memory_used_bytes do %>
                <div>
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-xs font-medium text-gray-600">VRAM</span>
                    <span class="text-xs font-mono text-gray-500">
                      {format_bytes_short(gpu.memory_used_bytes)} / {format_bytes_short(
                        gpu.memory_total_bytes
                      )}
                    </span>
                  </div>
                  <%= if gpu.memory_used_pct do %>
                    <.usage_bar pct={gpu.memory_used_pct} />
                  <% end %>
                </div>
              <% end %>

              <%= if gpu.temperature do %>
                <div class="flex items-center justify-between">
                  <span class="text-xs font-medium text-gray-600">Temp</span>
                  <span class={[
                    "text-xs font-mono",
                    gpu.temperature >= 85 && "text-red-600",
                    gpu.temperature >= 70 && gpu.temperature < 85 && "text-amber-600",
                    gpu.temperature < 70 && "text-gray-500"
                  ]}>
                    {round(gpu.temperature)}°C
                  </span>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>

        <%!-- Ollama Instances --%>
        <div>
          <span class="text-xs font-medium text-gray-600 block mb-2">Ollama Instances</span>
          <div class="space-y-1.5">
            <%= for inst <- @node.ollama_instances do %>
              <div class="flex items-center justify-between text-sm">
                <div class="flex items-center gap-2">
                  <span class={[
                    "inline-block w-1.5 h-1.5 rounded-full",
                    inst.online? && "bg-green-500",
                    !inst.online? && "bg-red-500"
                  ]}>
                  </span>
                  <span class="font-mono text-gray-700 text-xs">
                    {Enum.join(inst.tags, ", ")}
                  </span>
                </div>
                <div class="flex items-center gap-3 text-xs">
                  <span class="font-mono text-gray-500">
                    {if inst.ping_ms, do: "#{inst.ping_ms} ms", else: "—"}
                  </span>
                  <span class={[
                    "font-medium",
                    inst.busy && "text-amber-600",
                    !inst.busy && "text-gray-400"
                  ]}>
                    {if inst.busy, do: "Busy", else: "Idle"}
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :pct, :float, required: true

  defp usage_bar(assigns) do
    capped = min(assigns.pct, 100)

    color =
      cond do
        capped >= 90 -> "bg-red-500"
        capped >= 70 -> "bg-amber-500"
        capped >= 50 -> "bg-blue-500"
        true -> "bg-green-500"
      end

    assigns =
      assigns
      |> assign(:capped, capped)
      |> assign(:color, color)

    ~H"""
    <div class="w-full bg-gray-100 rounded-full h-2">
      <div class={["h-2 rounded-full transition-all", @color]} style={"width: #{@capped}%"}></div>
    </div>
    <div class="text-right mt-0.5">
      <span class="text-xs font-mono text-gray-500">{Float.round(@pct, 1)}%</span>
    </div>
    """
  end

  defp format_bytes_short(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{round(bytes)} B"
    end
  end

  defp format_bytes_short(_), do: "—"

  defp short_cpu_name(name) when is_binary(name) do
    name
    |> String.replace(~r/\(R\)|\(TM\)/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp short_cpu_name(_), do: "Unknown"

  defp short_gpu_name("NVIDIA " <> rest), do: rest
  defp short_gpu_name(name) when is_binary(name), do: name
  defp short_gpu_name(_), do: "Unknown GPU"

  defp format_freq(hz) when is_number(hz) do
    ghz = hz / 1.0e9

    if ghz >= 1 do
      "#{Float.round(ghz, 1)} GHz"
    else
      "#{round(hz / 1.0e6)} MHz"
    end
  end

  defp section(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div class="bg-gray-50 px-4 py-3 border-b border-gray-200">
        <h2 class="text-sm font-semibold text-gray-700">{@title}</h2>
      </div>
      <div class="divide-y divide-gray-100">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, default: nil
  slot :inner_block

  defp row(assigns) do
    ~H"""
    <div class="flex justify-between items-center px-4 py-2.5">
      <span class="text-sm text-gray-500">{@label}</span>
      <span class="text-sm font-mono text-gray-900">
        <%= if @inner_block != [] do %>
          {render_slot(@inner_block)}
        <% else %>
          {@value}
        <% end %>
      </span>
    </div>
    """
  end
end
