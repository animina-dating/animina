defmodule Animina.Monitoring.PrometheusClientTest do
  use ExUnit.Case, async: true

  alias Animina.Monitoring.PrometheusClient

  @sample_metrics """
  # HELP node_memory_MemTotal_bytes Memory information field MemTotal_bytes.
  # TYPE node_memory_MemTotal_bytes gauge
  node_memory_MemTotal_bytes 6.7379503104e+10
  # HELP node_memory_MemAvailable_bytes Memory information field MemAvailable_bytes.
  # TYPE node_memory_MemAvailable_bytes gauge
  node_memory_MemAvailable_bytes 1.9327676416e+10
  # HELP node_load1 1m load average.
  # TYPE node_load1 gauge
  node_load1 2.45
  # HELP node_load5 5m load average.
  # TYPE node_load5 gauge
  node_load5 1.89
  # HELP node_load15 15m load average.
  # TYPE node_load15 gauge
  node_load15 1.23
  # HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
  # TYPE node_cpu_seconds_total counter
  node_cpu_seconds_total{cpu="0",mode="idle"} 123456.78
  node_cpu_seconds_total{cpu="0",mode="system"} 1234.56
  node_cpu_seconds_total{cpu="1",mode="idle"} 123400.12
  node_cpu_seconds_total{cpu="1",mode="system"} 1200.34
  node_cpu_seconds_total{cpu="2",mode="idle"} 123300.99
  node_cpu_seconds_total{cpu="3",mode="idle"} 123200.88
  """

  describe "parse_prometheus_text/1" do
    test "parses metrics without labels" do
      text = """
      node_load1 2.45
      node_load5 1.89
      """

      result = PrometheusClient.parse_prometheus_text(text)

      assert {"node_load1", %{}, 2.45} in result
      assert {"node_load5", %{}, 1.89} in result
    end

    test "parses metrics with labels" do
      text = ~s|node_cpu_seconds_total{cpu="0",mode="idle"} 123456.78|

      [{name, labels, value}] = PrometheusClient.parse_prometheus_text(text)

      assert name == "node_cpu_seconds_total"
      assert labels == %{"cpu" => "0", "mode" => "idle"}
      assert value == 123_456.78
    end

    test "skips comment lines" do
      text = """
      # HELP node_load1 1m load average.
      # TYPE node_load1 gauge
      node_load1 2.45
      """

      result = PrometheusClient.parse_prometheus_text(text)
      assert length(result) == 1
      assert {"node_load1", %{}, 2.45} in result
    end

    test "skips empty lines" do
      text = """
      node_load1 2.45

      node_load5 1.89

      """

      result = PrometheusClient.parse_prometheus_text(text)
      assert length(result) == 2
    end

    test "handles empty input" do
      assert PrometheusClient.parse_prometheus_text("") == []
    end

    test "handles nil input" do
      assert PrometheusClient.parse_prometheus_text(nil) == []
    end

    test "handles malformed lines gracefully" do
      text = """
      node_load1 2.45
      this is not a valid metric line
      node_load5 1.89
      """

      result = PrometheusClient.parse_prometheus_text(text)
      assert length(result) == 2
    end

    test "parses scientific notation values" do
      text = "node_memory_MemTotal_bytes 6.7379503104e+10"

      [{_name, _labels, value}] = PrometheusClient.parse_prometheus_text(text)
      assert_in_delta value, 67_379_503_104, 1
    end
  end

  describe "extract_node_metrics/1" do
    test "extracts memory, load, and CPU metrics from parsed data" do
      parsed = PrometheusClient.parse_prometheus_text(@sample_metrics)
      metrics = PrometheusClient.extract_node_metrics(parsed)

      assert_in_delta metrics.memory_total_bytes, 67_379_503_104, 1
      assert_in_delta metrics.memory_available_bytes, 19_327_676_416, 1

      assert metrics.memory_used_bytes ==
               metrics.memory_total_bytes - metrics.memory_available_bytes

      assert metrics.load1 == 2.45
      assert metrics.load5 == 1.89
      assert metrics.load15 == 1.23
      assert metrics.cpu_count == 4
    end

    test "computes memory used percentage" do
      parsed = PrometheusClient.parse_prometheus_text(@sample_metrics)
      metrics = PrometheusClient.extract_node_metrics(parsed)

      expected_pct =
        (metrics.memory_total_bytes - metrics.memory_available_bytes) / metrics.memory_total_bytes *
          100

      assert_in_delta metrics.memory_used_pct, expected_pct, 0.1
    end

    test "computes load percentage relative to CPU count" do
      parsed = PrometheusClient.parse_prometheus_text(@sample_metrics)
      metrics = PrometheusClient.extract_node_metrics(parsed)

      # load_pct = load1 / cpu_count * 100 = 2.45 / 4 * 100 = 61.25
      assert_in_delta metrics.load_pct, 61.25, 0.1
    end

    test "returns nil for empty parsed data" do
      assert PrometheusClient.extract_node_metrics([]) == nil
    end

    test "returns nil when essential metrics are missing" do
      parsed = [{"some_other_metric", %{}, 42.0}]
      assert PrometheusClient.extract_node_metrics(parsed) == nil
    end
  end
end
