defmodule Animina.AITest do
  use Animina.DataCase, async: true

  alias Animina.AI

  describe "enqueue/3" do
    test "creates a pending job" do
      assert {:ok, job} = AI.enqueue("spellcheck", %{"text" => "Hello"})
      assert job.status == "pending"
      assert job.job_type == "spellcheck"
      assert job.params == %{"text" => "Hello"}
      assert job.priority == 20
    end

    test "uses module default priority" do
      assert {:ok, job} = AI.enqueue("gender_guess", %{"name" => "stefan"})
      assert job.priority == 10
    end

    test "allows overriding priority" do
      assert {:ok, job} =
               AI.enqueue("photo_classification", %{"photo_id" => Ecto.UUID.generate()},
                 priority: 40
               )

      assert job.priority == 40
    end

    test "raises on unknown job type" do
      assert_raise ArgumentError, ~r/Unknown job type/, fn ->
        AI.enqueue("nonexistent", %{})
      end
    end
  end

  describe "queue management" do
    test "cancel/1 cancels a pending job" do
      {:ok, job} = AI.enqueue("spellcheck", %{"text" => "test"})
      assert {:ok, cancelled} = AI.cancel(job.id)
      assert cancelled.status == "cancelled"
    end

    test "cancel/1 rejects non-pending jobs" do
      {:ok, job} = AI.enqueue("spellcheck", %{"text" => "test"})
      {:ok, _} = AI.mark_running(job)
      assert {:error, :not_cancellable} = AI.cancel(job.id)
    end

    test "retry/1 resets failed job to pending" do
      {:ok, job} = AI.enqueue("spellcheck", %{"text" => "test"})
      {:ok, running} = AI.mark_running(job)

      # Mark as failed (max_attempts=1 so it goes to failed)
      {:ok, failed} = AI.mark_failed(running, "test error")
      assert failed.status == "failed"

      {:ok, retried} = AI.retry(failed.id)
      assert retried.status == "pending"
    end
  end

  describe "queue_stats/0" do
    test "returns counts by status" do
      stats = AI.queue_stats()
      assert is_integer(stats.pending)
      assert is_integer(stats.running)
      assert is_integer(stats.completed)
      assert is_integer(stats.failed)
      assert is_integer(stats.cancelled)
    end
  end

  describe "list_runnable_jobs/1" do
    test "returns pending jobs sorted by priority then age" do
      {:ok, low} = AI.enqueue("wingman_suggestion", %{"prompt" => "test"}, priority: 50)
      {:ok, high} = AI.enqueue("gender_guess", %{"name" => "test"})

      jobs = AI.list_runnable_jobs(10)
      ids = Enum.map(jobs, & &1.id)

      # gender_guess (P10) should come before wingman_suggestion at P50
      assert Enum.find_index(ids, &(&1 == high.id)) < Enum.find_index(ids, &(&1 == low.id))
    end
  end

  describe "count_jobs/1" do
    test "counts all jobs" do
      {:ok, _} = AI.enqueue("spellcheck", %{"text" => "test"})
      assert AI.count_jobs() >= 1
    end

    test "counts by status" do
      {:ok, _} = AI.enqueue("spellcheck", %{"text" => "test"})
      assert AI.count_jobs(status: "pending") >= 1
    end
  end

  describe "mark_running/1 and mark_completed/2" do
    test "transitions pending → running → completed" do
      {:ok, job} = AI.enqueue("spellcheck", %{"text" => "test"})
      assert job.status == "pending"

      {:ok, running} = AI.mark_running(job)
      assert running.status == "running"
      assert running.attempt == 1

      {:ok, completed} =
        AI.mark_completed(running, %{
          result: %{"corrected_text" => "test"},
          model: "qwen3:8b",
          server_url: "http://localhost:11434/api",
          prompt: "test",
          raw_response: "test",
          duration_ms: 100
        })

      assert completed.status == "completed"
    end
  end

  describe "mark_failed/3 with retries" do
    test "retries by setting back to pending with delay" do
      {:ok, job} = AI.enqueue("photo_classification", %{"photo_id" => Ecto.UUID.generate()})
      {:ok, running} = AI.mark_running(job)

      # max_attempts is 10, so first failure should retry
      {:ok, retried} = AI.mark_failed(running, "transient error")
      assert retried.status == "pending"
      assert retried.scheduled_at != nil
    end
  end

  describe "has_pending_job?/3" do
    test "returns true when matching pending job exists" do
      subject_id = Ecto.UUID.generate()

      {:ok, _} =
        AI.enqueue("photo_classification", %{"photo_id" => subject_id},
          subject_type: "Photo",
          subject_id: subject_id
        )

      assert AI.has_pending_job?("photo_classification", "Photo", subject_id)
    end

    test "returns false when no matching job exists" do
      refute AI.has_pending_job?("photo_classification", "Photo", Ecto.UUID.generate())
    end
  end
end
