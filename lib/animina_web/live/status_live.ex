defmodule AniminaWeb.StatusLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Scope
  alias Animina.AI.Queue
  alias Animina.Monitoring.PrometheusClient

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
      |> assign(:load_history, %{})
      |> assign(:gpu_load_history, %{})
      |> assign(:load_sparkline_window, "15m")
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

  def handle_event("set_load_window", %{"window" => window}, socket)
      when window in ["15m", "60m"] do
    {:noreply, assign(socket, :load_sparkline_window, window)}
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

    # Accumulate CPU load history per host
    prev_load_history = Map.get(socket.assigns, :load_history, %{})
    now = System.monotonic_time(:second)

    load_history =
      Enum.reduce(hosts_ordered, prev_load_history, fn host, hist ->
        case node_metrics_map do
          %{^host => %{load_pct: pct}} when is_number(pct) ->
            prev = Map.get(hist, host, [])
            Map.put(hist, host, Enum.take([{now, pct} | prev], 720))

          _ ->
            hist
        end
      end)

    # Accumulate GPU load history per host per GPU UUID
    prev_gpu_load_history = Map.get(socket.assigns, :gpu_load_history, %{})

    gpu_load_history =
      Enum.reduce(hosts_ordered, prev_gpu_load_history, fn host, hist ->
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

    socket
    |> assign(:gpu_cache, gpu_cache)
    |> assign(:load_history, load_history)
    |> assign(:gpu_load_history, gpu_load_history)
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
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold">Server Nodes</h2>
          <div class="flex gap-1">
            <%= for {key, label} <- [{"15m", "15m"}, {"60m", "60m"}] do %>
              <button
                phx-click="set_load_window"
                phx-value-window={key}
                class={[
                  "px-2.5 py-1 text-xs font-medium rounded",
                  if(@load_sparkline_window == key,
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
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <%= for node <- @server_nodes do %>
            <.server_node_card node={node} load_sparkline_window={@load_sparkline_window} />
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

        <%!-- Deployment Info --%>
        <h2 class="text-lg font-semibold mb-4">Last Deployment to All Nodes</h2>
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
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :node, :map, required: true
  attr :load_sparkline_window, :string, required: true

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
            <.sparkline data={@node.load_history} window={@load_sparkline_window} />
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
                  <.sparkline
                    data={Map.get(@node.gpu_load_history, gpu.uuid, [])}
                    window={@load_sparkline_window}
                    label="GPU Load History"
                    color="#8b5cf6"
                  />
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

  defp window_seconds("15m"), do: 15 * 60
  defp window_seconds(_), do: 60 * 60

  @sparkline_w 200
  @sparkline_h 60

  attr :data, :list, required: true
  attr :window, :string, required: true
  attr :label, :string, default: "CPU Load History"
  attr :color, :string, default: "#3b82f6"

  defp sparkline(assigns) do
    assigns = prepare_sparkline_assigns(assigns)

    ~H"""
    <div data-testid="cpu-sparkline" class="mt-2 border border-gray-100 rounded bg-gray-50/50 p-2">
      <div class="flex items-center justify-between mb-1">
        <span class="text-[10px] font-medium text-gray-500">{@label}</span>
        <span class="text-[10px] font-mono text-gray-400">
          <%= if @has_data? do %>
            min {format_pct(@min_val)} · max {format_pct(@max_val)} · now {format_pct(@current)}
          <% else %>
            collecting data…
          <% end %>
        </span>
      </div>
      <div class="relative">
        <%!-- Y-axis labels --%>
        <div
          class="absolute left-0 top-0 bottom-0 flex flex-col justify-between text-[8px] font-mono text-gray-400 pr-1"
          style="width: 28px;"
        >
          <span>{format_pct_short(@y_max)}</span>
          <span>{format_pct_short(@y_max / 2)}</span>
          <span>0%</span>
        </div>
        <%!-- Chart area --%>
        <div style="margin-left: 30px;">
          <svg
            viewBox={"0 0 #{@sparkline_w} #{@sparkline_h}"}
            preserveAspectRatio="none"
            class="w-full"
            style="height: 60px;"
          >
            <%!-- Grid lines --%>
            <line
              x1="0"
              y1="0"
              x2={@sparkline_w}
              y2="0"
              stroke="#e5e7eb"
              stroke-width="0.5"
              stroke-dasharray="3,3"
            />
            <line
              x1="0"
              y1={@sparkline_h / 2}
              x2={@sparkline_w}
              y2={@sparkline_h / 2}
              stroke="#e5e7eb"
              stroke-width="0.5"
              stroke-dasharray="3,3"
            />
            <line
              x1="0"
              y1={@sparkline_h}
              x2={@sparkline_w}
              y2={@sparkline_h}
              stroke="#e5e7eb"
              stroke-width="0.5"
            />
            <%!-- Vertical tick marks --%>
            <%= for {tx, _label} <- @x_ticks do %>
              <line
                x1={tx}
                y1="0"
                x2={tx}
                y2={@sparkline_h}
                stroke="#f3f4f6"
                stroke-width="0.5"
              />
            <% end %>
            <%!-- Area fill + Line (only when data exists) --%>
            <%= if @has_data? do %>
              <polygon
                points={sparkline_polygon(@positioned, @y_max, @sparkline_h)}
                fill={@color}
                fill-opacity="0.08"
              />
              <polyline
                points={sparkline_line(@positioned, @y_max, @sparkline_h)}
                fill="none"
                stroke={@color}
                stroke-width="1.5"
                stroke-linejoin="round"
              />
            <% end %>
          </svg>
        </div>
      </div>
      <%!-- X-axis time labels --%>
      <div
        class="relative text-[8px] font-mono text-gray-400"
        style="margin-left: 30px; height: 12px;"
      >
        <%= for {tx, label} <- @x_ticks do %>
          <span
            class="absolute"
            style={"left: #{tx / @sparkline_w * 100}%; transform: translateX(-50%);"}
          >
            {label}
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  defp prepare_sparkline_assigns(%{data: data} = assigns) when length(data) < 2 do
    window_secs = window_seconds(assigns.window)
    tick_step = if assigns.window == "15m", do: 5 * 60, else: 15 * 60
    tick_count = div(window_secs, tick_step)

    x_ticks =
      for i <- 0..tick_count do
        age = window_secs - i * tick_step
        x = Float.round((@sparkline_w - 1) * (1 - age / window_secs), 1)
        label = if age == 0, do: "now", else: "#{div(age, 60)}m"
        {x, label}
      end

    assigns
    |> assign(:has_data?, false)
    |> assign(:positioned, [])
    |> assign(:y_max, 100)
    |> assign(:current, 0)
    |> assign(:min_val, 0)
    |> assign(:max_val, 0)
    |> assign(:x_ticks, x_ticks)
    |> assign(:sparkline_w, @sparkline_w)
    |> assign(:sparkline_h, @sparkline_h)
  end

  defp prepare_sparkline_assigns(assigns) do
    window_secs = window_seconds(assigns.window)
    now_t = assigns.data |> hd() |> elem(0)

    positioned =
      assigns.data
      |> Enum.reverse()
      |> Enum.map(fn {t, pct} ->
        age = now_t - t
        x = Float.round((@sparkline_w - 1) * (1 - age / window_secs), 1)
        {x, pct}
      end)
      |> Enum.filter(fn {x, _} -> x >= 0 end)

    pct_values = Enum.map(positioned, &elem(&1, 1))

    tick_step = if assigns.window == "15m", do: 5 * 60, else: 15 * 60
    tick_count = div(window_secs, tick_step)

    x_ticks =
      for i <- 0..tick_count do
        age = window_secs - i * tick_step
        x = Float.round((@sparkline_w - 1) * (1 - age / window_secs), 1)
        label = if age == 0, do: "now", else: "#{div(age, 60)}m"
        {x, label}
      end

    assigns
    |> assign(:has_data?, true)
    |> assign(:positioned, positioned)
    |> assign(:y_max, pct_values |> Enum.max() |> max(100))
    |> assign(:current, List.last(pct_values))
    |> assign(:min_val, Enum.min(pct_values))
    |> assign(:max_val, Enum.max(pct_values))
    |> assign(:x_ticks, x_ticks)
    |> assign(:sparkline_w, @sparkline_w)
    |> assign(:sparkline_h, @sparkline_h)
  end

  defp format_pct(val), do: "#{Float.round(val / 1, 1)}%"

  defp format_pct_short(val) when val >= 100, do: "#{round(val)}%"
  defp format_pct_short(val), do: "#{round(val)}%"

  defp sparkline_line(positioned, y_max, height) do
    Enum.map_join(positioned, " ", fn {x, pct} ->
      y = Float.round(height - pct / y_max * height, 1)
      "#{x},#{y}"
    end)
  end

  defp sparkline_polygon(positioned, y_max, height) do
    line =
      Enum.map_join(positioned, " ", fn {x, pct} ->
        y = Float.round(height - pct / y_max * height, 1)
        "#{x},#{y}"
      end)

    {first_x, _} = hd(positioned)
    {last_x, _} = List.last(positioned)
    "#{first_x},#{height} #{line} #{last_x},#{height}"
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
