defmodule Animina.Monitoring.PrometheusClient do
  @moduledoc """
  Fetches and parses Prometheus Node Exporter metrics from remote server nodes.
  """

  require Logger

  @default_port 9100
  @default_gpu_port 9835
  @http_timeout 4_000

  @doc """
  Fetches node metrics from a Prometheus Node Exporter endpoint.
  Returns a metrics map or nil on failure.
  """
  def fetch_node_metrics(host) do
    port = node_exporter_port()
    url = "http://#{host}:#{port}/metrics"

    case Req.get(url,
           retry: false,
           receive_timeout: @http_timeout,
           connect_options: [timeout: @http_timeout]
         ) do
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
  Fetches GPU metrics from an nvidia_gpu_exporter endpoint.
  Returns a list of GPU maps or an empty list on failure.
  """
  def fetch_gpu_metrics(host) do
    url = "http://#{host}:#{gpu_exporter_port()}/metrics"
    result = fetch_and_parse_gpu(url, host)
    log_gpu_result(result, url)
  rescue
    e ->
      Logger.warning("GPU exporter #{host}:#{@default_gpu_port}: #{inspect(e)}")
      []
  end

  defp fetch_and_parse_gpu(url, _host) do
    case Req.get(url,
           retry: false,
           receive_timeout: @http_timeout,
           connect_options: [timeout: @http_timeout]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_prometheus_text(body)}

      {:ok, %{status: status}} ->
        {:http_error, status}

      {:error, reason} ->
        {:conn_error, reason}
    end
  end

  defp log_gpu_result({:ok, parsed}, url) do
    gpus = extract_gpu_metrics(parsed)

    if gpus == [] do
      nvidia_count =
        Enum.count(parsed, fn {name, _, _} -> String.starts_with?(name, "nvidia_smi") end)

      Logger.warning(
        "GPU exporter #{url}: #{length(parsed)} metrics (#{nvidia_count} nvidia), 0 GPUs extracted"
      )
    end

    gpus
  end

  defp log_gpu_result({:http_error, status}, url) do
    Logger.warning("GPU exporter #{url}: HTTP #{status}")
    []
  end

  defp log_gpu_result({:conn_error, reason}, url) do
    Logger.debug("GPU exporter #{url}: #{inspect(reason)}")
    []
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

    cpu_model = extract_cpu_model(parsed)
    cpu_max_freq_hz = extract_cpu_max_freq(parsed)

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
        cpu_model: cpu_model,
        cpu_max_freq_hz: cpu_max_freq_hz,
        load_pct: if(load_pct, do: Float.round(load_pct, 1), else: nil)
      }
    else
      nil
    end
  end

  @doc """
  Extracts GPU metrics from parsed nvidia_gpu_exporter Prometheus data.
  Returns a list of maps, one per GPU.
  """
  def extract_gpu_metrics([]), do: []

  def extract_gpu_metrics(parsed) do
    gpu_infos =
      parsed
      |> Enum.filter(fn {name, _, _} -> name == "nvidia_smi_gpu_info" end)
      |> Enum.map(fn {_, labels, _} -> {labels["uuid"], labels["name"]} end)
      |> Enum.reject(fn {uuid, _} -> is_nil(uuid) end)

    case gpu_infos do
      [] ->
        []

      _ ->
        lookup = Map.new(parsed, fn {name, labels, value} -> {{name, labels["uuid"]}, value} end)
        Enum.map(gpu_infos, &build_gpu_map(&1, lookup))
    end
  end

  defp build_gpu_map({uuid, name}, lookup) do
    mem_total = lookup[{"nvidia_smi_memory_total_bytes", uuid}]
    mem_used = lookup[{"nvidia_smi_memory_used_bytes", uuid}]
    temp = lookup[{"nvidia_smi_temperature_gpu", uuid}]
    util = lookup[{"nvidia_smi_utilization_gpu_ratio", uuid}]

    mem_used_pct =
      if mem_total && mem_used && mem_total > 0,
        do: Float.round(mem_used / mem_total * 100, 1),
        else: nil

    %{
      uuid: uuid,
      name: name,
      memory_total_bytes: mem_total,
      memory_used_bytes: mem_used,
      memory_used_pct: mem_used_pct,
      temperature: temp,
      utilization_pct: if(util, do: Float.round(util * 100, 1), else: nil)
    }
  end

  # --- Extraction helpers ---

  defp extract_cpu_model(parsed) do
    # Try node_cpu_info (node_exporter 1.6+), then node_cpu_model_info (textfile fallback)
    Enum.find_value(parsed, fn
      {"node_cpu_info", labels, _} -> labels["model_name"]
      _ -> nil
    end) ||
      Enum.find_value(parsed, fn
        {"node_cpu_model_info", labels, _} -> labels["model_name"]
        _ -> nil
      end)
  end

  defp extract_cpu_max_freq(parsed) do
    parsed
    |> Enum.filter(fn {name, _, _} -> name == "node_cpu_frequency_max_hertz" end)
    |> Enum.map(fn {_, _, value} -> value end)
    |> Enum.max(fn -> nil end)
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

  defp gpu_exporter_port do
    case Application.get_env(:animina, __MODULE__) do
      config when is_list(config) -> Keyword.get(config, :gpu_exporter_port, @default_gpu_port)
      _ -> @default_gpu_port
    end
  end
end
