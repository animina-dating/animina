defmodule Mix.Tasks.Benchmark.Ollama do
  @shortdoc "Benchmarks the running Ollama instance at varying concurrency levels"
  @moduledoc """
  Benchmarks the currently running Ollama instance by sending real photo
  classification requests at varying concurrency levels.

  Bypasses the app's Semaphore/HealthTracker for clean measurement.
  Uses the production prompt from PhotoProcessor.

  ## Usage

      mix benchmark.ollama [options]

  ## Options

      --count N           Number of test photos (default: 20)
      --concurrency LIST  Comma-separated concurrency levels (default: "1,2,4,6,8")
      --model MODEL       Override model (default: from feature flags / config)
      --warmup N          Warmup requests before measuring (default: 2)
      --csv PATH          Write results to CSV file
      --gpu-monitor       Capture nvidia-smi GPU utilization during runs
      --timeout MS        Per-request timeout in ms (default: 120000)
      --url URL           Ollama base URL (default: from config)

  ## Examples

      # Quick test with current Ollama config
      mix benchmark.ollama --count 10 --concurrency "1,2,4"

      # Full benchmark with CSV output
      mix benchmark.ollama --csv results.csv --gpu-monitor

      # Test a specific model
      mix benchmark.ollama --model "qwen3-vl:4b" --count 15
  """
  use Mix.Task

  alias Animina.AI.Client, as: AIClient
  alias Animina.Photos.PhotoProcessor

  @default_count 20
  @default_concurrency [1, 2, 4, 6, 8]
  @default_warmup 2
  @default_timeout 120_000

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          count: :integer,
          concurrency: :string,
          model: :string,
          warmup: :integer,
          csv: :string,
          gpu_monitor: :boolean,
          timeout: :integer,
          url: :string
        ]
      )

    # Start the app so we can read config and use Ollama
    Mix.Task.run("app.start")

    config = build_config(opts)

    print_header(config)

    photos = discover_photos(config.count)

    if Enum.empty?(photos) do
      Mix.shell().error("No photos found in uploads/processed/**/*_thumb.webp")
      System.halt(1)
    end

    warn_if_ai_running()

    images = encode_photos(photos)

    warmup(config, List.first(images))

    results =
      Enum.map(config.concurrency_levels, fn level ->
        run_benchmark(config, images, level)
      end)

    print_results_table(results, config)
    print_recommendation(results)

    if config.csv_path do
      write_csv(results, config)
    end
  end

  # ── Config ──────────────────────────────────────────────────────────

  defp build_config(opts) do
    url =
      Keyword.get(opts, :url) ||
        Animina.AI.config(:ollama_url, "http://localhost:11434/api")

    model =
      Keyword.get(opts, :model) ||
        try do
          AIClient.default_model()
        rescue
          _ -> "qwen3-vl:8b"
        end

    concurrency_levels =
      case Keyword.get(opts, :concurrency) do
        nil ->
          @default_concurrency

        str ->
          str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.to_integer/1)
      end

    %{
      count: Keyword.get(opts, :count, @default_count),
      concurrency_levels: concurrency_levels,
      model: model,
      warmup_count: Keyword.get(opts, :warmup, @default_warmup),
      csv_path: Keyword.get(opts, :csv),
      gpu_monitor: Keyword.get(opts, :gpu_monitor, false),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      url: url
    }
  end

  # ── Photo Discovery ─────────────────────────────────────────────────

  defp discover_photos(count) do
    pattern = "uploads/processed/**/*_thumb.webp"

    paths =
      Path.wildcard(pattern)
      |> Enum.shuffle()
      |> Enum.take(count)

    Mix.shell().info("Found #{length(paths)} photos for benchmarking")
    paths
  end

  defp encode_photos(paths) do
    Enum.map(paths, fn path ->
      path
      |> File.read!()
      |> Base.encode64()
    end)
  end

  # ── Warnings ────────────────────────────────────────────────────────

  defp warn_if_ai_running do
    case GenServer.whereis(Animina.AI.Semaphore) do
      nil ->
        :ok

      pid ->
        if Process.alive?(pid) do
          Mix.shell().info("\n⚠  AI services are running. They may compete for GPU resources.")

          Mix.shell().info(
            "   For clean results, stop them first or ensure the queue is empty.\n"
          )
        end
    end
  end

  # ── Warmup ──────────────────────────────────────────────────────────

  defp warmup(config, sample_image) do
    Mix.shell().info("\nWarming up model #{config.model} (#{config.warmup_count} requests)...")

    client = Ollama.init(base_url: config.url, receive_timeout: config.timeout)
    prompt = PhotoProcessor.ollama_prompt()

    Enum.each(1..config.warmup_count, fn i ->
      case Ollama.completion(client,
             model: config.model,
             prompt: prompt,
             images: [sample_image],
             keep_alive: "60m"
           ) do
        {:ok, _} ->
          Mix.shell().info("  Warmup #{i}/#{config.warmup_count} ✓")

        {:error, reason} ->
          Mix.shell().error("  Warmup #{i}/#{config.warmup_count} FAILED: #{inspect(reason)}")
      end
    end)

    Mix.shell().info("Warmup complete.\n")
  end

  # ── Benchmark Run ───────────────────────────────────────────────────

  defp run_benchmark(config, images, concurrency) do
    Mix.shell().info("Running concurrency=#{concurrency} with #{length(images)} photos...")

    gpu_task = if config.gpu_monitor, do: start_gpu_monitor(), else: nil

    start_time = System.monotonic_time(:millisecond)

    results =
      images
      |> Task.async_stream(
        fn image -> single_request(config, image) end,
        max_concurrency: concurrency,
        timeout: config.timeout + 10_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, :task_timeout, 0, %{}}
      end)

    wall_time_ms = System.monotonic_time(:millisecond) - start_time

    gpu_stats = if gpu_task, do: stop_gpu_monitor(gpu_task), else: nil

    aggregate_results(results, concurrency, wall_time_ms, gpu_stats)
  end

  defp single_request(config, image) do
    client = Ollama.init(base_url: config.url, receive_timeout: config.timeout)
    prompt = PhotoProcessor.ollama_prompt()

    start = System.monotonic_time(:millisecond)

    case Ollama.completion(client,
           model: config.model,
           prompt: prompt,
           images: [image],
           keep_alive: "60m"
         ) do
      {:ok, response} ->
        latency = System.monotonic_time(:millisecond) - start

        timing = %{
          total_duration_ns: Map.get(response, "total_duration", 0),
          eval_duration_ns: Map.get(response, "eval_duration", 0),
          eval_count: Map.get(response, "eval_count", 0),
          prompt_eval_duration_ns: Map.get(response, "prompt_eval_duration", 0),
          prompt_eval_count: Map.get(response, "prompt_eval_count", 0)
        }

        {:ok, latency, timing}

      {:error, reason} ->
        latency = System.monotonic_time(:millisecond) - start
        {:error, reason, latency, %{}}
    end
  end

  # ── Stats Aggregation ───────────────────────────────────────────────

  defp aggregate_results(results, concurrency, wall_time_ms, gpu_stats) do
    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _, _} -> true
        _ -> false
      end)

    latencies =
      successes
      |> Enum.map(fn {:ok, latency, _} -> latency end)
      |> Enum.sort()

    timings = Enum.map(successes, fn {:ok, _, timing} -> timing end)

    total_count = length(results)
    success_count = length(successes)
    failure_count = length(failures)

    latency_stats =
      if Enum.empty?(latencies) do
        %{avg: 0, p50: 0, p95: 0, p99: 0, min: 0, max: 0}
      else
        %{
          avg: Enum.sum(latencies) / length(latencies),
          p50: percentile(latencies, 50),
          p95: percentile(latencies, 95),
          p99: percentile(latencies, 99),
          min: List.first(latencies),
          max: List.last(latencies)
        }
      end

    # Aggregate Ollama native timing
    tokens_per_sec =
      timings
      |> Enum.map(fn t ->
        eval_dur = Map.get(t, :eval_duration_ns, 0)
        eval_count = Map.get(t, :eval_count, 0)

        if eval_dur > 0 do
          eval_count / (eval_dur / 1_000_000_000)
        else
          0.0
        end
      end)
      |> then(fn rates ->
        if Enum.empty?(rates), do: 0.0, else: Enum.sum(rates) / length(rates)
      end)

    throughput = if wall_time_ms > 0, do: success_count / (wall_time_ms / 60_000), else: 0.0

    %{
      concurrency: concurrency,
      total: total_count,
      successes: success_count,
      failures: failure_count,
      success_rate: if(total_count > 0, do: success_count / total_count * 100, else: 0),
      wall_time_ms: wall_time_ms,
      throughput_per_min: throughput,
      latency: latency_stats,
      tokens_per_sec: tokens_per_sec,
      gpu_stats: gpu_stats
    }
  end

  defp percentile([_ | _] = sorted_list, p) do
    len = length(sorted_list)
    k = p / 100 * (len - 1)
    f = trunc(k)
    c = f + 1

    if c >= len do
      Enum.at(sorted_list, f)
    else
      lower = Enum.at(sorted_list, f)
      upper = Enum.at(sorted_list, c)
      lower + (k - f) * (upper - lower)
    end
  end

  defp percentile(_, _), do: 0

  # ── GPU Monitoring ──────────────────────────────────────────────────

  defp start_gpu_monitor do
    parent = self()

    spawn_link(fn ->
      gpu_loop(parent, [])
    end)
  end

  defp gpu_loop(parent, samples) do
    receive do
      :stop ->
        send(parent, {:gpu_samples, samples})
    after
      1000 ->
        sample = capture_gpu_sample()
        gpu_loop(parent, [sample | samples])
    end
  end

  defp stop_gpu_monitor(pid) do
    send(pid, :stop)

    receive do
      {:gpu_samples, samples} ->
        aggregate_gpu_samples(samples)
    after
      5000 -> nil
    end
  end

  defp capture_gpu_sample do
    case System.cmd("nvidia-smi", [
           "--query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu",
           "--format=csv,noheader,nounits"
         ]) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(fn line ->
          line
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&parse_number/1)
        end)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {n, _} -> n
      :error -> 0.0
    end
  end

  defp aggregate_gpu_samples(samples) do
    samples = Enum.reject(samples, &is_nil/1)

    if Enum.empty?(samples) do
      nil
    else
      # Flatten — each sample may have multiple GPUs
      all_gpus = List.flatten(samples)

      gpu_utils = Enum.map(all_gpus, fn [gpu, _, _, _, _] -> gpu end)
      mem_utils = Enum.map(all_gpus, fn [_, mem, _, _, _] -> mem end)
      temps = Enum.map(all_gpus, fn [_, _, _, _, temp] -> temp end)

      %{
        avg_gpu_util: safe_avg(gpu_utils),
        max_gpu_util: Enum.max(gpu_utils, fn -> 0 end),
        avg_mem_util: safe_avg(mem_utils),
        avg_temp: safe_avg(temps)
      }
    end
  end

  defp safe_avg([]), do: 0.0
  defp safe_avg(list), do: Enum.sum(list) / length(list)

  # ── Output ──────────────────────────────────────────────────────────

  defp print_header(config) do
    Mix.shell().info("""

    ═══════════════════════════════════════════════════════
      Ollama Benchmark
    ═══════════════════════════════════════════════════════
      URL:          #{config.url}
      Model:        #{config.model}
      Photos:       #{config.count}
      Concurrency:  #{Enum.join(config.concurrency_levels, ", ")}
      Timeout:      #{config.timeout}ms
      GPU monitor:  #{config.gpu_monitor}
    ═══════════════════════════════════════════════════════
    """)
  end

  defp print_results_table(results, config) do
    Mix.shell().info("""

    ───────────────────────────────────────────────────────────────────────────────────────────────────
      Results: #{config.model} @ #{config.url}
    ───────────────────────────────────────────────────────────────────────────────────────────────────
    """)

    header =
      String.pad_trailing("Conc", 6) <>
        String.pad_trailing("Wall(s)", 9) <>
        String.pad_trailing("Thru/min", 10) <>
        String.pad_trailing("Avg(s)", 9) <>
        String.pad_trailing("P50(s)", 9) <>
        String.pad_trailing("P95(s)", 9) <>
        String.pad_trailing("P99(s)", 9) <>
        String.pad_trailing("Min(s)", 9) <>
        String.pad_trailing("Max(s)", 9) <>
        String.pad_trailing("Tok/s", 8) <>
        String.pad_trailing("OK%", 6) <>
        gpu_header(results)

    Mix.shell().info("  #{header}")

    Mix.shell().info("  #{String.duplicate("─", String.length(header))}")

    Enum.each(results, fn r ->
      row =
        String.pad_trailing("#{r.concurrency}", 6) <>
          String.pad_trailing(format_seconds(r.wall_time_ms), 9) <>
          String.pad_trailing(:erlang.float_to_binary(r.throughput_per_min, decimals: 1), 10) <>
          String.pad_trailing(format_seconds(r.latency.avg), 9) <>
          String.pad_trailing(format_seconds(r.latency.p50), 9) <>
          String.pad_trailing(format_seconds(r.latency.p95), 9) <>
          String.pad_trailing(format_seconds(r.latency.p99), 9) <>
          String.pad_trailing(format_seconds(r.latency.min), 9) <>
          String.pad_trailing(format_seconds(r.latency.max), 9) <>
          String.pad_trailing(:erlang.float_to_binary(r.tokens_per_sec, decimals: 1), 8) <>
          String.pad_trailing(:erlang.float_to_binary(r.success_rate, decimals: 0), 6) <>
          gpu_row(r)

      Mix.shell().info("  #{row}")
    end)

    Mix.shell().info("")
  end

  defp gpu_header(results) do
    if Enum.any?(results, fn r -> r.gpu_stats != nil end) do
      String.pad_trailing("GPU%", 7) <> String.pad_trailing("Temp", 6)
    else
      ""
    end
  end

  defp gpu_row(%{gpu_stats: nil}), do: ""

  defp gpu_row(%{gpu_stats: stats}) do
    String.pad_trailing(:erlang.float_to_binary(stats.avg_gpu_util, decimals: 0), 7) <>
      String.pad_trailing(:erlang.float_to_binary(stats.avg_temp, decimals: 0), 6)
  end

  defp format_seconds(ms) when is_number(ms) do
    :erlang.float_to_binary(ms / 1000, decimals: 1)
  end

  defp format_seconds(_), do: "-"

  defp print_recommendation(results) do
    # Best = highest throughput where p95 < 30s and success rate >= 95%
    eligible =
      Enum.filter(results, fn r ->
        r.latency.p95 < 30_000 and r.success_rate >= 95
      end)

    case Enum.max_by(eligible, & &1.throughput_per_min, fn -> nil end) do
      nil ->
        Mix.shell().info("  No configuration met the criteria (p95 < 30s, success >= 95%).")

        Mix.shell().info("  Consider reducing photo count or checking GPU resources.\n")

      best ->
        Mix.shell().info("""
          Recommendation: concurrency=#{best.concurrency}
            Throughput: #{:erlang.float_to_binary(best.throughput_per_min, decimals: 1)} photos/min
            P95 latency: #{format_seconds(best.latency.p95)}s
            Success rate: #{:erlang.float_to_binary(best.success_rate, decimals: 0)}%
        """)
    end
  end

  # ── CSV Output ──────────────────────────────────────────────────────

  defp write_csv(results, config) do
    # Ensure output directory exists
    dir = Path.dirname(config.csv_path)

    if dir != "." do
      File.mkdir_p!(dir)
    end

    headers = [
      "model",
      "concurrency",
      "total_photos",
      "successes",
      "failures",
      "success_rate",
      "wall_time_ms",
      "throughput_per_min",
      "avg_ms",
      "p50_ms",
      "p95_ms",
      "p99_ms",
      "min_ms",
      "max_ms",
      "tokens_per_sec",
      "avg_gpu_util",
      "avg_mem_util",
      "avg_temp"
    ]

    rows =
      Enum.map(results, fn r ->
        gpu = r.gpu_stats || %{}

        [
          config.model,
          r.concurrency,
          r.total,
          r.successes,
          r.failures,
          Float.round(r.success_rate, 1),
          r.wall_time_ms,
          Float.round(r.throughput_per_min, 2),
          Float.round(r.latency.avg / 1, 1),
          Float.round(r.latency.p50 / 1, 1),
          Float.round(r.latency.p95 / 1, 1),
          Float.round(r.latency.p99 / 1, 1),
          Float.round(r.latency.min / 1, 1),
          Float.round(r.latency.max / 1, 1),
          Float.round(r.tokens_per_sec, 2),
          Map.get(gpu, :avg_gpu_util, ""),
          Map.get(gpu, :avg_mem_util, ""),
          Map.get(gpu, :avg_temp, "")
        ]
        |> Enum.join(",")
      end)

    content = [Enum.join(headers, ",") | rows] |> Enum.join("\n")

    File.write!(config.csv_path, content <> "\n")
    Mix.shell().info("Results written to #{config.csv_path}")
  end
end
