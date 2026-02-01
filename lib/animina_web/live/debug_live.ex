defmodule AniminaWeb.DebugLive do
  use AniminaWeb, :live_view

  alias Ecto.Adapters.SQL

  @refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, assign(socket, page_title: "System Debug") |> assign_metrics()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()
    {:noreply, assign_metrics(socket)}
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto py-8 px-4">
        <h1 class="text-2xl font-bold mb-8">System Debug</h1>

        <div class="grid grid-cols-2 gap-6">
          <%!-- Deployment --%>
          <.section title="Deployment">
            <.row label="Deployed At" value={@deployed_at} />
            <.row label="Uptime" value={@uptime} />
          </.section>

          <%!-- Versions --%>
          <.section title="Versions">
            <.row label="ANIMINA" value={@app_version} />
            <.row label="Elixir" value={@elixir_version} />
            <.row label="Erlang/OTP" value={@otp_version} />
          </.section>

          <%!-- System Load --%>
          <.section title="System Load">
            <%= if @load_averages == :not_available do %>
              <.row label="Status" value="N/A" />
            <% else %>
              <.row label="1 min" value={elem(@load_averages, 0)} />
              <.row label="5 min" value={elem(@load_averages, 1)} />
              <.row label="15 min" value={elem(@load_averages, 2)} />
            <% end %>
          </.section>

          <%!-- BEAM Memory --%>
          <.section title="BEAM Memory">
            <.row label="Total" value={@beam_memory.total} />
            <.row label="Processes" value={@beam_memory.processes} />
            <.row label="ETS" value={@beam_memory.ets} />
            <.row label="Atoms" value={@beam_memory.atoms} />
            <.row label="Binaries" value={@beam_memory.binaries} />
          </.section>

          <%!-- System Memory --%>
          <.section title="System Memory">
            <%= if @system_memory == :not_available do %>
              <.row label="Status" value="N/A (not Linux)" />
            <% else %>
              <.row label="Total" value={@system_memory.total} />
              <.row label="Available" value={@system_memory.available} />
              <.row label="Used" value={@system_memory.used} />
            <% end %>
          </.section>

          <%!-- Database --%>
          <.section title="Database">
            <.row label="PostgreSQL">
              <span class={[
                "inline-flex items-center gap-1 font-medium",
                @db_status == :ok && "text-green-600",
                @db_status == :error && "text-red-600"
              ]}>
                {if @db_status == :ok, do: "● Connected", else: "● Unreachable"}
              </span>
            </.row>
          </.section>

          <%!-- BEAM / CPU Info --%>
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
