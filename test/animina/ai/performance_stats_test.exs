defmodule Animina.AI.PerformanceStatsTest do
  use Animina.DataCase, async: false

  alias Animina.AI
  alias Animina.AI.Job
  alias Animina.AI.PerformanceStats

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
    updated_at = Keyword.get(opts, :updated_at, DateTime.utc_now())

    {:ok, job} = AI.enqueue(job_type, params)
    {:ok, _running} = AI.mark_running(job)

    {1, [updated]} =
      from(j in Job, where: j.id == ^job.id and j.status == "running", select: j)
      |> Repo.update_all(
        set: [
          status: "completed",
          server_url: server_url,
          duration_ms: duration_ms,
          updated_at: updated_at
        ]
      )

    updated
  end

  describe "avg_duration_ms/2" do
    test "returns average duration for completed jobs on tagged instances" do
      set_ollama_instances([gpu_instance(), cpu_instance()])

      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 1000)
      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 2000)
      create_completed_job(server_url: "http://cpu:11434/api", duration_ms: 5000)

      assert PerformanceStats.avg_duration_ms("gpu", "gender_guess") == 1500
      assert PerformanceStats.avg_duration_ms("cpu", "gender_guess") == 5000
    end

    test "filters by job_type" do
      set_ollama_instances([gpu_instance()])

      create_completed_job(
        job_type: "gender_guess",
        server_url: "http://gpu:11434/api",
        duration_ms: 1000
      )

      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://gpu:11434/api",
        duration_ms: 5000
      )

      assert PerformanceStats.avg_duration_ms("gpu", "gender_guess") == 1000
      assert PerformanceStats.avg_duration_ms("gpu", "photo_description") == 5000
    end

    test "returns nil when no completed jobs exist" do
      set_ollama_instances([gpu_instance()])
      assert is_nil(PerformanceStats.avg_duration_ms("gpu", "gender_guess"))
    end

    test "returns nil when tag has no configured instances" do
      set_ollama_instances([gpu_instance()])
      assert is_nil(PerformanceStats.avg_duration_ms("cpu", "gender_guess"))
    end

    test "only considers jobs from the last 24 hours" do
      set_ollama_instances([gpu_instance()])

      old = DateTime.utc_now() |> DateTime.add(-25, :hour)

      create_completed_job(
        server_url: "http://gpu:11434/api",
        duration_ms: 1000,
        updated_at: old
      )

      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 3000)

      # Old job should be excluded, only the 3000ms job counts
      assert PerformanceStats.avg_duration_ms("gpu", "gender_guess") == 3000
    end

    test "ignores jobs with zero or nil duration" do
      set_ollama_instances([gpu_instance()])

      create_completed_job(server_url: "http://gpu:11434/api", duration_ms: 2000)

      # Create a job with 0 duration (shouldn't count)
      {:ok, zero_job} = AI.enqueue("gender_guess", %{"name" => "zero"})
      {:ok, _} = AI.mark_running(zero_job)

      from(j in Job, where: j.id == ^zero_job.id and j.status == "running")
      |> Repo.update_all(
        set: [status: "completed", server_url: "http://gpu:11434/api", duration_ms: 0]
      )

      assert PerformanceStats.avg_duration_ms("gpu", "gender_guess") == 2000
    end
  end

  describe "avg_duration_ms_all/1" do
    test "returns average across all job types for a tag" do
      set_ollama_instances([gpu_instance()])

      create_completed_job(
        job_type: "gender_guess",
        server_url: "http://gpu:11434/api",
        duration_ms: 1000
      )

      create_completed_job(
        job_type: "photo_description",
        params: %{"photo_id" => Ecto.UUID.generate()},
        server_url: "http://gpu:11434/api",
        duration_ms: 3000
      )

      # Average of 1000 and 3000 = 2000
      assert PerformanceStats.avg_duration_ms_all("gpu") == 2000
    end

    test "returns nil when no data exists" do
      set_ollama_instances([gpu_instance()])
      assert is_nil(PerformanceStats.avg_duration_ms_all("gpu"))
    end
  end

  describe "gpu_busy?/0" do
    test "returns false when no jobs are running" do
      set_ollama_instances([gpu_instance()])
      refute PerformanceStats.gpu_busy?()
    end

    test "returns true when running jobs >= GPU instance count" do
      set_ollama_instances([gpu_instance()])

      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      AI.mark_running(job)

      assert PerformanceStats.gpu_busy?()
    end

    test "returns false when running jobs < GPU instance count (multiple GPUs)" do
      set_ollama_instances([
        gpu_instance(),
        %{url: "http://gpu2:11434/api", timeout: 120_000, priority: 1, tags: ["gpu"]}
      ])

      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      AI.mark_running(job)

      # 1 running < 2 GPUs
      refute PerformanceStats.gpu_busy?()
    end

    test "returns false when no GPU instances configured" do
      set_ollama_instances([cpu_instance()])
      refute PerformanceStats.gpu_busy?()
    end
  end

  describe "oldest_running_elapsed_ms/0" do
    test "returns nil when no jobs are running" do
      assert is_nil(PerformanceStats.oldest_running_elapsed_ms())
    end

    test "returns elapsed time for oldest running job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      AI.mark_running(job)

      elapsed = PerformanceStats.oldest_running_elapsed_ms()
      assert is_integer(elapsed)
      assert elapsed >= 0
      assert elapsed < 5000
    end

    test "returns elapsed time of the oldest job when multiple are running" do
      {:ok, job1} = AI.enqueue("gender_guess", %{"name" => "first"})
      {:ok, running1} = AI.mark_running(job1)

      # Backdate the first job to simulate it being older
      from(j in Job, where: j.id == ^running1.id)
      |> Repo.update_all(
        set: [updated_at: DateTime.utc_now() |> DateTime.add(-10, :second)]
      )

      {:ok, job2} = AI.enqueue("gender_guess", %{"name" => "second"})
      AI.mark_running(job2)

      elapsed = PerformanceStats.oldest_running_elapsed_ms()
      # Should be at least ~10 seconds for the older job
      assert elapsed >= 9000
    end
  end
end
