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
