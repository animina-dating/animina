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
  # HELP node_cpu_info CPU information from /proc/cpuinfo.
  # TYPE node_cpu_info gauge
  node_cpu_info{cachesize="16384 KB",core="0",cpu="0",family="6",model="85",model_name="Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz",package="0",stepping="4",vendor="GenuineIntel"} 1
  node_cpu_info{cachesize="16384 KB",core="1",cpu="1",family="6",model="85",model_name="Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz",package="0",stepping="4",vendor="GenuineIntel"} 1
  node_cpu_info{cachesize="16384 KB",core="2",cpu="2",family="6",model="85",model_name="Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz",package="0",stepping="4",vendor="GenuineIntel"} 1
  node_cpu_info{cachesize="16384 KB",core="3",cpu="3",family="6",model="85",model_name="Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz",package="0",stepping="4",vendor="GenuineIntel"} 1
  # HELP node_cpu_frequency_max_hertz Maximum cpu thread frequency in hertz.
  # TYPE node_cpu_frequency_max_hertz gauge
  node_cpu_frequency_max_hertz{cpu="0"} 4.2e+09
  node_cpu_frequency_max_hertz{cpu="1"} 4.2e+09
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
      assert metrics.cpu_model == "Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz"
      assert_in_delta metrics.cpu_max_freq_hz, 4.2e9, 1
    end

    test "returns nil cpu_model when node_cpu_info is absent" do
      text = """
      node_memory_MemTotal_bytes 6.7379503104e+10
      node_memory_MemAvailable_bytes 1.9327676416e+10
      node_load1 2.45
      node_load5 1.89
      node_load15 1.23
      node_cpu_seconds_total{cpu="0",mode="idle"} 123456.78
      """

      parsed = PrometheusClient.parse_prometheus_text(text)
      metrics = PrometheusClient.extract_node_metrics(parsed)

      assert metrics.cpu_model == nil
      assert metrics.cpu_max_freq_hz == nil
      assert metrics.cpu_count == 1
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

    test "extracts cpu_model from textfile node_cpu_model_info fallback" do
      text = """
      node_memory_MemTotal_bytes 6.7379503104e+10
      node_memory_MemAvailable_bytes 1.9327676416e+10
      node_load1 2.45
      node_load5 1.89
      node_load15 1.23
      node_cpu_seconds_total{cpu="0",mode="idle"} 123456.78
      node_cpu_model_info{model_name="AMD EPYC 9654 96-Core Processor",cores="96"} 1
      """

      parsed = PrometheusClient.parse_prometheus_text(text)
      metrics = PrometheusClient.extract_node_metrics(parsed)

      assert metrics.cpu_model == "AMD EPYC 9654 96-Core Processor"
    end

    test "returns nil for empty parsed data" do
      assert PrometheusClient.extract_node_metrics([]) == nil
    end

    test "returns nil when essential metrics are missing" do
      parsed = [{"some_other_metric", %{}, 42.0}]
      assert PrometheusClient.extract_node_metrics(parsed) == nil
    end
  end

  @sample_gpu_metrics """
  # HELP nvidia_smi_gpu_info A metric with a constant '1' value with GPU information.
  # TYPE nvidia_smi_gpu_info gauge
  nvidia_smi_gpu_info{uuid="GPU-abc123",name="NVIDIA GeForce RTX 3090",driver_version="535.183.01",pstate="P2",index="0"} 1
  # HELP nvidia_smi_memory_total_bytes Total installed GPU memory.
  # TYPE nvidia_smi_memory_total_bytes gauge
  nvidia_smi_memory_total_bytes{uuid="GPU-abc123",name="NVIDIA GeForce RTX 3090"} 2.5769803776e+10
  # HELP nvidia_smi_memory_used_bytes GPU memory currently used.
  # TYPE nvidia_smi_memory_used_bytes gauge
  nvidia_smi_memory_used_bytes{uuid="GPU-abc123",name="NVIDIA GeForce RTX 3090"} 1.2e+10
  # HELP nvidia_smi_memory_free_bytes GPU memory currently free.
  # TYPE nvidia_smi_memory_free_bytes gauge
  nvidia_smi_memory_free_bytes{uuid="GPU-abc123",name="NVIDIA GeForce RTX 3090"} 1.3769803776e+10
  # HELP nvidia_smi_temperature_gpu GPU temperature in celsius.
  # TYPE nvidia_smi_temperature_gpu gauge
  nvidia_smi_temperature_gpu{uuid="GPU-abc123",name="NVIDIA GeForce RTX 3090"} 65
  # HELP nvidia_smi_utilization_gpu_ratio GPU utilization ratio.
  # TYPE nvidia_smi_utilization_gpu_ratio gauge
  nvidia_smi_utilization_gpu_ratio{uuid="GPU-abc123",name="NVIDIA GeForce RTX 3090"} 0.85
  """

  @sample_multi_gpu_metrics """
  nvidia_smi_gpu_info{uuid="GPU-aaa",name="NVIDIA A100-SXM4-80GB",driver_version="535.183.01",index="0"} 1
  nvidia_smi_gpu_info{uuid="GPU-bbb",name="NVIDIA A100-SXM4-80GB",driver_version="535.183.01",index="1"} 1
  nvidia_smi_memory_total_bytes{uuid="GPU-aaa",name="NVIDIA A100-SXM4-80GB"} 8.589934592e+10
  nvidia_smi_memory_total_bytes{uuid="GPU-bbb",name="NVIDIA A100-SXM4-80GB"} 8.589934592e+10
  nvidia_smi_memory_used_bytes{uuid="GPU-aaa",name="NVIDIA A100-SXM4-80GB"} 4.0e+10
  nvidia_smi_memory_used_bytes{uuid="GPU-bbb",name="NVIDIA A100-SXM4-80GB"} 2.0e+10
  nvidia_smi_temperature_gpu{uuid="GPU-aaa",name="NVIDIA A100-SXM4-80GB"} 72
  nvidia_smi_temperature_gpu{uuid="GPU-bbb",name="NVIDIA A100-SXM4-80GB"} 58
  nvidia_smi_utilization_gpu_ratio{uuid="GPU-aaa",name="NVIDIA A100-SXM4-80GB"} 0.95
  nvidia_smi_utilization_gpu_ratio{uuid="GPU-bbb",name="NVIDIA A100-SXM4-80GB"} 0.3
  """

  describe "extract_gpu_metrics/1" do
    test "extracts single GPU info" do
      parsed = PrometheusClient.parse_prometheus_text(@sample_gpu_metrics)
      gpus = PrometheusClient.extract_gpu_metrics(parsed)

      assert length(gpus) == 1
      [gpu] = gpus

      assert gpu.name == "NVIDIA GeForce RTX 3090"
      assert_in_delta gpu.memory_total_bytes, 25_769_803_776, 1
      assert_in_delta gpu.memory_used_bytes, 1.2e10, 1
      assert gpu.temperature == 65.0
      assert gpu.utilization_pct == 85.0
    end

    test "extracts multiple GPUs" do
      parsed = PrometheusClient.parse_prometheus_text(@sample_multi_gpu_metrics)
      gpus = PrometheusClient.extract_gpu_metrics(parsed)

      assert length(gpus) == 2

      gpu_a = Enum.find(gpus, &(&1.uuid == "GPU-aaa"))
      gpu_b = Enum.find(gpus, &(&1.uuid == "GPU-bbb"))

      assert gpu_a.name == "NVIDIA A100-SXM4-80GB"
      assert gpu_a.temperature == 72.0
      assert gpu_a.utilization_pct == 95.0

      assert gpu_b.temperature == 58.0
      assert gpu_b.utilization_pct == 30.0
    end

    test "computes memory used percentage" do
      parsed = PrometheusClient.parse_prometheus_text(@sample_gpu_metrics)
      [gpu] = PrometheusClient.extract_gpu_metrics(parsed)

      expected_pct = 1.2e10 / 25_769_803_776 * 100
      assert_in_delta gpu.memory_used_pct, expected_pct, 0.1
    end

    test "returns empty list when no GPU metrics present" do
      parsed = PrometheusClient.parse_prometheus_text(@sample_metrics)
      assert PrometheusClient.extract_gpu_metrics(parsed) == []
    end

    test "returns empty list for empty input" do
      assert PrometheusClient.extract_gpu_metrics([]) == []
    end
  end
end
