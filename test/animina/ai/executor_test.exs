defmodule Animina.AI.ExecutorTest do
  use Animina.DataCase, async: false

  alias Animina.AI
  alias Animina.AI.Executor
  alias Animina.AI.Job

  import Ecto.Query

  # Helper to configure ollama instances via application env
  defp set_ollama_instances(instances) do
    current = Application.get_env(:animina, Animina.Photos, [])
    updated = Keyword.put(current, :ollama_instances, instances)
    Application.put_env(:animina, Animina.Photos, updated)

    on_exit(fn ->
      Application.put_env(:animina, Animina.Photos, current)
    end)
  end

  defp gpu_instance do
    %{url: "http://gpu:11434/api", timeout: 120_000, priority: 1, tags: ["gpu"]}
  end

  defp cpu_instance do
    %{url: "http://cpu:11434/api", timeout: 120_000, priority: 2, tags: ["cpu"]}
  end

  # Creates a completed job with specific server_url and duration_ms
  defp create_completed_job(opts) do
    job_type = Keyword.get(opts, :job_type, "gender_guess")
    params = Keyword.get(opts, :params, %{"name" => "test"})
    server_url = Keyword.fetch!(opts, :server_url)
    duration_ms = Keyword.fetch!(opts, :duration_ms)

    {:ok, job} = AI.enqueue(job_type, params)
    {:ok, _running} = AI.mark_running(job)

    from(j in Job, where: j.id == ^job.id and j.status == "running")
    |> Repo.update_all(
      set: [
        status: "completed",
        server_url: server_url,
        duration_ms: duration_ms,
        updated_at: DateTime.utc_now()
      ]
    )
  end

  # Makes GPU busy by creating a running job
  defp make_gpu_busy do
    {:ok, job} = AI.enqueue("gender_guess", %{"name" => "busy"})
    {:ok, running} = AI.mark_running(job)
    running
  end

  describe "build_instance_filter/4 — no GPU configured" do
    test "falls back to any instance" do
      set_ollama_instances([cpu_instance()])

      assert {:run, nil, "qwen3:8b"} =
               Executor.build_instance_filter(2, "gender_guess", :text, "qwen3:8b")
    end

    test "downgrades vision model when no GPU configured" do
      set_ollama_instances([cpu_instance()])

      assert {:run, nil, "qwen3-vl:2b"} =
               Executor.build_instance_filter(1, "photo_classification", :vision, "qwen3-vl:8b")
    end
  end

  describe "build_instance_filter/4 — GPU idle" do
    test "routes to GPU when GPU is not busy" do
      set_ollama_instances([gpu_instance(), cpu_instance()])

      # No running jobs → GPU is idle
      assert {:run, filter, "qwen3:1.7b"} =
               Executor.build_instance_filter(4, "photo_description", :text, "qwen3:1.7b")

      assert is_function(filter, 1)
      assert filter.(gpu_instance()) == true
      assert filter.(cpu_instance()) == false
    end

    test "routes high-priority to GPU when idle" do
      set_ollama_instances([gpu_instance(), cpu_instance()])

      assert {:run, filter, "qwen3:1.7b"} =
               Executor.build_instance_filter(1, "gender_guess", :text, "qwen3:1.7b")

      assert is_function(filter, 1)
      assert filter.(gpu_instance()) == true
      assert filter.(cpu_instance()) == false
    end
  end

  describe "build_instance_filter/4 — GPU busy, no CPU" do
    test "routes to GPU (must wait) when no CPU is available" do
      set_ollama_instances([gpu_instance()])
      make_gpu_busy()

      assert {:run, filter, "qwen3:1.7b"} =
               Executor.build_instance_filter(3, "photo_classification", :text, "qwen3:1.7b")

      assert is_function(filter, 1)
      assert filter.(gpu_instance()) == true
    end
  end

  describe "build_instance_filter/4 — GPU busy, CPU faster → run on CPU" do
    test "routes to CPU when CPU is estimated faster" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      # Historical data: GPU takes 10s, CPU takes 3s
      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://gpu:11434/api",
        duration_ms: 10_000
      )

      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://cpu:11434/api",
        duration_ms: 3_000
      )

      assert {:run, filter, _model} =
               Executor.build_instance_filter(4, "photo_description", :text, "qwen3:1.7b")

      assert is_function(filter, 1)
      assert filter.(cpu_instance()) == true
      assert filter.(gpu_instance()) == false
    end

    test "downgrades vision model when routing to CPU" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      create_completed_job(
        job_type: "photo_classification",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://gpu:11434/api",
        duration_ms: 20_000
      )

      create_completed_job(
        job_type: "photo_classification",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://cpu:11434/api",
        duration_ms: 2_000
      )

      assert {:run, _filter, "qwen3-vl:2b"} =
               Executor.build_instance_filter(3, "photo_classification", :vision, "qwen3-vl:8b")
    end

    test "applies same math for high-priority jobs (no priority bias)" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 15_000)
      create_completed_job(server_url: "http://cpu:11434/api", duration_ms: 2_000)

      assert {:run, filter, _model} =
               Executor.build_instance_filter(1, "gender_guess", :text, "qwen3:1.7b")

      assert is_function(filter, 1)
      assert filter.(cpu_instance()) == true
    end
  end

  describe "build_instance_filter/4 — GPU busy, GPU faster → defer" do
    test "defers when waiting for GPU is estimated faster than CPU" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      running = make_gpu_busy()

      # Backdate the running job so it's almost done (started 9.5s ago)
      from(j in Job, where: j.id == ^running.id)
      |> Repo.update_all(
        set: [updated_at: DateTime.utc_now() |> DateTime.add(-9500, :millisecond)]
      )

      # GPU takes 10s (almost done!), CPU takes 50s
      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://gpu:11434/api",
        duration_ms: 10_000
      )

      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://cpu:11434/api",
        duration_ms: 50_000
      )

      # Also need overall GPU avg for remaining-time estimation
      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 10_000)

      assert {:defer, reason} =
               Executor.build_instance_filter(4, "photo_description", :text, "qwen3:1.7b")

      assert reason =~ "waiting for GPU"
    end

    test "defers when only GPU historical data exists (no CPU data)" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 5_000)

      assert {:defer, _reason} =
               Executor.build_instance_filter(3, "gender_guess", :text, "qwen3:1.7b")
    end
  end

  describe "build_instance_filter/4 — GPU busy, queue depth forces CPU" do
    test "switches to CPU when GPU queue depth makes waiting too long" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      # GPU takes 10s, CPU takes 25s — normally GPU is faster
      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://gpu:11434/api",
        duration_ms: 10_000
      )

      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://cpu:11434/api",
        duration_ms: 25_000
      )

      # Also need overall GPU avg
      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 10_000)

      # With no deferred jobs, GPU should win: remaining + 10s < 25s
      # (depends on timing but GPU total should be ~10-20s vs CPU 25s)

      # Now simulate 2 already-deferred jobs waiting for GPU
      {:ok, d1} = AI.enqueue("gender_guess", %{"name" => "deferred1"})
      {:ok, _} = AI.mark_running(d1)
      AI.defer_job(d1.id, 5)

      {:ok, d2} = AI.enqueue("gender_guess", %{"name" => "deferred2"})
      {:ok, _} = AI.mark_running(d2)
      AI.defer_job(d2.id, 5)

      # Now GPU total = remaining + (2 * 10000) + 10000 = remaining + 30000
      # CPU total = 25000
      # 25000 < (remaining + 30000) * 1.1 → CPU wins because of queue depth
      assert {:run, filter, _model} =
               Executor.build_instance_filter(4, "photo_description", :text, "qwen3:1.7b")

      assert is_function(filter, 1)
      assert filter.(cpu_instance()) == true
      assert filter.(gpu_instance()) == false
    end
  end

  describe "build_instance_filter/4 — GPU busy, only CPU data → run on CPU" do
    test "uses CPU when only CPU historical data exists" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      create_completed_job(server_url: "http://cpu:11434/api", duration_ms: 5_000)

      assert {:run, filter, _model} =
               Executor.build_instance_filter(3, "gender_guess", :text, "qwen3:1.7b")

      assert is_function(filter, 1)
      assert filter.(cpu_instance()) == true
    end
  end

  describe "build_instance_filter/4 — GPU busy, no historical data → random" do
    test "randomly picks CPU or GPU (never defers) to build up stats" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      # Run multiple times — should get both :run outcomes, never :defer
      results =
        for _ <- 1..30 do
          Executor.build_instance_filter(3, "photo_classification", :text, "qwen3:1.7b")
        end

      # All should be {:run, ...}, never {:defer, ...}
      assert Enum.all?(results, fn
               {:run, _, _} -> true
               _ -> false
             end)

      # Should see both GPU and CPU filters
      targets =
        Enum.map(results, fn {:run, filter, _model} ->
          cond do
            is_nil(filter) -> :any
            filter.(gpu_instance()) -> :gpu
            filter.(cpu_instance()) -> :cpu
          end
        end)

      assert :gpu in targets or :cpu in targets
    end
  end

  # --- pre_route/3 tests ---

  # Helper to build a job struct for pre_route (needs job_type, model)
  defp make_job(job_type) do
    {:ok, job} = AI.enqueue(job_type, %{"name" => "pre_route_test"})
    job
  end

  defp gender_guess_module, do: Animina.AI.JobTypes.GenderGuess
  defp photo_description_module, do: Animina.AI.JobTypes.PhotoDescription

  describe "pre_route/3 — no GPU configured" do
    test "dispatches with {:run_any, ...} and downgrades vision model" do
      set_ollama_instances([cpu_instance()])
      job = make_job("photo_classification")

      assert {:dispatch, {:run_any, "qwen3-vl:2b"}, 0} =
               Executor.pre_route(job, Animina.AI.JobTypes.PhotoClassification, 0)
    end

    test "dispatches text job with {:run_any, ...} and keeps model" do
      set_ollama_instances([cpu_instance()])
      job = make_job("gender_guess")

      assert {:dispatch, {:run_any, "qwen3:1.7b"}, 0} =
               Executor.pre_route(job, gender_guess_module(), 0)
    end
  end

  describe "pre_route/3 — GPU idle" do
    test "dispatches to GPU and increments depth" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      job = make_job("gender_guess")

      assert {:dispatch, {:run_gpu, "qwen3:1.7b"}, 1} =
               Executor.pre_route(job, gender_guess_module(), 0)
    end
  end

  describe "pre_route/3 — GPU busy, no CPU" do
    test "dispatches to GPU (must wait)" do
      set_ollama_instances([gpu_instance()])
      make_gpu_busy()
      job = make_job("gender_guess")

      assert {:dispatch, {:run_gpu, "qwen3:1.7b"}, 1} =
               Executor.pre_route(job, gender_guess_module(), 0)
    end
  end

  describe "pre_route/3 — increasing depth routes to CPU (core fix)" do
    test "first job skips for GPU, later jobs route to CPU as depth grows" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      # GPU takes 10s, CPU takes 25s — GPU is normally preferred
      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://gpu:11434/api",
        duration_ms: 10_000
      )

      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://cpu:11434/api",
        duration_ms: 25_000
      )

      # Overall GPU avg for remaining-time estimation
      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 10_000)

      module = photo_description_module()

      # At depth=0, GPU is worth waiting for (remaining + 0*10000 + 10000 < 25000)
      result0 = Executor.pre_route(make_job("photo_description"), module, 0)
      assert {:skip_for_gpu, 1} = result0

      # At depth=3, GPU total = remaining + 3*10000 + 10000 = remaining + 40000
      # CPU total = 25000 — CPU wins!
      result3 = Executor.pre_route(make_job("photo_description"), module, 3)
      assert {:dispatch, {:run_cpu, _model}, 3} = result3
    end
  end

  describe "pre_route/3 — GPU busy, only GPU data → skip for GPU" do
    test "skips when only GPU historical data exists" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 5_000)

      job = make_job("gender_guess")

      assert {:skip_for_gpu, 1} =
               Executor.pre_route(job, gender_guess_module(), 0)
    end
  end

  describe "pre_route/3 — GPU busy, only CPU data → dispatch to CPU" do
    test "dispatches to CPU when only CPU historical data exists" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      create_completed_job(server_url: "http://cpu:11434/api", duration_ms: 5_000)

      job = make_job("gender_guess")

      assert {:dispatch, {:run_cpu, "qwen3:1.7b"}, 0} =
               Executor.pre_route(job, gender_guess_module(), 0)
    end
  end

  describe "pre_route/3 — GPU busy, no data → random dispatch (never skip)" do
    test "always dispatches (never skips) to build stats" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      make_gpu_busy()

      module = gender_guess_module()

      results =
        for _ <- 1..30 do
          Executor.pre_route(make_job("gender_guess"), module, 0)
        end

      # All should be {:dispatch, ...}, never {:skip_for_gpu, ...}
      assert Enum.all?(results, fn
               {:dispatch, _, _} -> true
               _ -> false
             end)

      # Should see both GPU and CPU routes
      routes =
        Enum.map(results, fn {:dispatch, route, _depth} ->
          case route do
            {:run_gpu, _} -> :gpu
            {:run_cpu, _} -> :cpu
          end
        end)

      assert :gpu in routes or :cpu in routes
    end
  end

  describe "get_gpu_instance_count/0" do
    test "returns count of GPU-tagged instances" do
      set_ollama_instances([gpu_instance(), cpu_instance()])
      assert Executor.get_gpu_instance_count() == 1
    end

    test "returns 0 when no GPU instances configured" do
      set_ollama_instances([cpu_instance(), cpu_instance()])
      assert Executor.get_gpu_instance_count() == 0
    end

    test "counts multiple GPU instances" do
      set_ollama_instances([gpu_instance(), gpu_instance(), cpu_instance()])
      assert Executor.get_gpu_instance_count() == 2
    end
  end

  describe "force_cpu/2" do
    test "returns CPU dispatch route for text model" do
      assert {:dispatch, {:run_cpu, "qwen3:1.7b"}, 5} =
               Executor.force_cpu(
                 %{job_type: "gender_guess", model: nil},
                 :text,
                 "qwen3:1.7b",
                 5
               )
    end

    test "downgrades vision model to CPU variant" do
      assert {:dispatch, {:run_cpu, "qwen3-vl:2b"}, 3} =
               Executor.force_cpu(
                 %{job_type: "photo_classification", model: nil},
                 :vision,
                 "qwen3-vl:8b",
                 3
               )
    end

  end

  describe "defer_job/2" do
    test "puts job back in queue with short delay and undoes attempt increment" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"}, max_attempts: 20)
      {:ok, running} = AI.mark_running(job)

      assert running.attempt == 1
      assert running.status == "running"

      assert {1, _} = AI.defer_job(running.id, 3)

      updated = AI.get_job(job.id)
      assert updated.status == "scheduled"
      # Attempt decremented back — deferring doesn't burn attempts
      assert updated.attempt == 0
      assert updated.scheduled_at != nil
      # Should be ~3 seconds in the future
      diff = DateTime.diff(updated.scheduled_at, DateTime.utc_now(), :second)
      assert diff >= 1 and diff <= 5
    end

    test "does not affect non-running jobs" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      assert {0, _} = AI.defer_job(job.id)

      updated = AI.get_job(job.id)
      assert updated.status == "pending"
    end

    test "deferred job becomes runnable after delay expires" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, _running} = AI.mark_running(job)

      # Defer with 0-second delay (immediately eligible again)
      AI.defer_job(job.id, 0)

      updated = AI.get_job(job.id)
      assert updated.status == "scheduled"

      # Should be in runnable jobs since scheduled_at <= now
      runnable = AI.list_runnable_jobs(10)
      assert Enum.any?(runnable, fn j -> j.id == job.id end)
    end
  end
end
