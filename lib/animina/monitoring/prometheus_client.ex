defmodule Animina.Monitoring.PrometheusClient do
  @moduledoc """
  Fetches and parses Prometheus Node Exporter metrics from remote server nodes.
  """

  @default_port 9100
  @http_timeout 4_000

  @doc """
  Fetches node metrics from a Prometheus Node Exporter endpoint.
  Returns a metrics map or nil on failure.
  """
  def fetch_node_metrics(host) do
    port = node_exporter_port()
    url = "http://#{host}:#{port}/metrics"

    case Req.get(url, receive_timeout: @http_timeout, connect_options: [timeout: @http_timeout]) do
      {:ok, %{status: 200, body: body}} ->
        body
        |> parse_prometheus_text()
        |> extract_node_metrics()

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Parses Prometheus text exposition format into a list of
  `{metric_name, labels_map, value}` tuples.
  """
  def parse_prometheus_text(nil), do: []
  def parse_prometheus_text(""), do: []

  def parse_prometheus_text(text) do
    text
    |> String.split("\n")
    |> Enum.reduce([], fn line, acc ->
      line = String.trim(line)

      cond do
        line == "" -> acc
        String.starts_with?(line, "#") -> acc
        true -> parse_metric_line(line, acc)
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Extracts structured node metrics from parsed Prometheus data.
  Returns a map with memory, load, and CPU info, or nil if essential data is missing.
  """
  def extract_node_metrics([]), do: nil

  def extract_node_metrics(parsed) do
    lookup = Map.new(parsed, fn {name, labels, value} -> {{name, labels}, value} end)

    mem_total = lookup[{"node_memory_MemTotal_bytes", %{}}]
    mem_available = lookup[{"node_memory_MemAvailable_bytes", %{}}]
    load1 = lookup[{"node_load1", %{}}]
    load5 = lookup[{"node_load5", %{}}]
    load15 = lookup[{"node_load15", %{}}]

    cpu_count =
      parsed
      |> Enum.filter(fn {name, _, _} -> name == "node_cpu_seconds_total" end)
      |> Enum.map(fn {_, labels, _} -> labels["cpu"] end)
      |> Enum.uniq()
      |> length()

    cpu_count = if cpu_count > 0, do: cpu_count, else: nil

    if mem_total && mem_available && load1 do
      mem_used = mem_total - mem_available
      mem_used_pct = mem_used / mem_total * 100
      load_pct = if cpu_count, do: load1 / cpu_count * 100, else: nil

      %{
        memory_total_bytes: mem_total,
        memory_available_bytes: mem_available,
        memory_used_bytes: mem_used,
        memory_used_pct: Float.round(mem_used_pct, 1),
        load1: load1,
        load5: load5,
        load15: load15,
        cpu_count: cpu_count,
        load_pct: if(load_pct, do: Float.round(load_pct, 1), else: nil)
      }
    else
      nil
    end
  end

  # --- Private ---

  defp parse_metric_line(line, acc) do
    case Regex.run(~r/^([a-zA-Z_:][a-zA-Z0-9_:]*)\{([^}]*)\}\s+(.+)$/, line) do
      [_, name, labels_str, value_str] ->
        prepend_if_valid(acc, name, parse_labels(labels_str), value_str)

      nil ->
        parse_metric_line_no_labels(line, acc)
    end
  end

  defp parse_metric_line_no_labels(line, acc) do
    case Regex.run(~r/^([a-zA-Z_:][a-zA-Z0-9_:]*)\s+(.+)$/, line) do
      [_, name, value_str] -> prepend_if_valid(acc, name, %{}, value_str)
      nil -> acc
    end
  end

  defp prepend_if_valid(acc, name, labels, value_str) do
    case parse_value(value_str) do
      nil -> acc
      value -> [{name, labels, value} | acc]
    end
  end

  defp parse_labels(labels_str) do
    ~r/([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"/
    |> Regex.scan(labels_str)
    |> Map.new(fn [_, key, val] -> {key, val} end)
  end

  defp parse_value(str) do
    str = String.trim(str)

    case Float.parse(str) do
      {val, ""} -> val
      {val, " " <> _} -> val
      _ -> nil
    end
  end

  defp node_exporter_port do
    case Application.get_env(:animina, __MODULE__) do
      config when is_list(config) -> Keyword.get(config, :node_exporter_port, @default_port)
      _ -> @default_port
    end
  end
end
