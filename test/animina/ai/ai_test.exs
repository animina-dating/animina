defmodule Animina.AITest do
  use Animina.DataCase, async: true

  alias Animina.AI
  alias Animina.AI.Job

  describe "enqueue/3" do
    test "creates a job with correct defaults for photo_classification" do
      assert {:ok, job} =
               AI.enqueue("photo_classification", %{"photo_id" => Ecto.UUID.generate()})

      assert job.job_type == "photo_classification"
      assert job.priority == 3
      assert job.max_attempts == 20
      assert job.status == "pending"
      assert job.attempt == 0
    end

    test "creates a job with correct defaults for gender_guess" do
      assert {:ok, job} = AI.enqueue("gender_guess", %{"name" => "alice"})

      assert job.job_type == "gender_guess"
      assert job.priority == 2
      assert job.max_attempts == 3
    end

    test "creates a job with correct defaults for photo_description" do
      assert {:ok, job} =
               AI.enqueue("photo_description", %{"photo_id" => Ecto.UUID.generate()})

      assert job.job_type == "photo_description"
      assert job.priority == 4
      assert job.max_attempts == 3
    end

    test "allows overriding priority" do
      assert {:ok, job} =
               AI.enqueue("photo_classification", %{"photo_id" => Ecto.UUID.generate()},
                 priority: 1
               )

      assert job.priority == 1
    end

    test "allows setting subject_type and subject_id" do
      photo_id = Ecto.UUID.generate()

      assert {:ok, job} =
               AI.enqueue("photo_classification", %{"photo_id" => photo_id},
                 subject_type: "Photo",
                 subject_id: photo_id
               )

      assert job.subject_type == "Photo"
      assert job.subject_id == photo_id
    end

    test "raises on unknown job type" do
      assert_raise ArgumentError, ~r/Unknown job type/, fn ->
        AI.enqueue("unknown_type", %{})
      end
    end
  end

  describe "cancel/1" do
    test "cancels a pending job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      assert {:ok, cancelled} = AI.cancel(job.id)
      assert cancelled.status == "cancelled"
    end

    test "cannot cancel a running job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      # Mark as running
      job
      |> Job.update_changeset(%{status: "running"})
      |> Repo.update!()

      assert {:error, :not_cancellable} = AI.cancel(job.id)
    end

    test "returns not_found for missing job" do
      assert {:error, :not_found} = AI.cancel(Ecto.UUID.generate())
    end
  end

  describe "retry/1" do
    test "retries a failed job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      job
      |> Job.update_changeset(%{status: "failed", error: "test error"})
      |> Repo.update!()

      assert {:ok, retried} = AI.retry(job.id)
      assert retried.status == "pending"
    end

    test "cannot retry a running job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      job
      |> Job.update_changeset(%{status: "running"})
      |> Repo.update!()

      assert {:error, :not_retryable} = AI.retry(job.id)
    end
  end

  describe "reprioritize/2" do
    test "changes priority of a pending job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      assert {:ok, updated} = AI.reprioritize(job.id, 1)
      assert updated.priority == 1
    end
  end

  describe "list_jobs/1" do
    test "lists jobs with pagination" do
      for i <- 1..3 do
        AI.enqueue("gender_guess", %{"name" => "test#{i}"})
      end

      result = AI.list_jobs(per_page: 2)
      assert length(result.entries) == 2
      assert result.total_count == 3
    end

    test "filters by job_type" do
      AI.enqueue("gender_guess", %{"name" => "test"})
      AI.enqueue("photo_description", %{"photo_id" => Ecto.UUID.generate()})

      result = AI.list_jobs(filter_job_type: "gender_guess")
      assert length(result.entries) == 1
      assert hd(result.entries).job_type == "gender_guess"
    end

    test "filters by status" do
      {:ok, job1} = AI.enqueue("gender_guess", %{"name" => "test1"})
      AI.enqueue("gender_guess", %{"name" => "test2"})

      job1
      |> Job.update_changeset(%{status: "completed"})
      |> Repo.update!()

      result = AI.list_jobs(filter_status: "pending")
      assert length(result.entries) == 1
    end
  end

  describe "queue_stats/0" do
    test "returns counts by status" do
      AI.enqueue("gender_guess", %{"name" => "test1"})

      {:ok, job2} = AI.enqueue("gender_guess", %{"name" => "test2"})

      job2
      |> Job.update_changeset(%{status: "completed"})
      |> Repo.update!()

      stats = AI.queue_stats()
      assert stats.pending >= 1
      assert stats.completed >= 1
    end
  end

  describe "list_runnable_jobs/1" do
    test "returns pending jobs ordered by priority then inserted_at" do
      {:ok, low} = AI.enqueue("gender_guess", %{"name" => "low"}, priority: 4)
      {:ok, high} = AI.enqueue("gender_guess", %{"name" => "high"}, priority: 1)

      jobs = AI.list_runnable_jobs(10)
      job_ids = Enum.map(jobs, & &1.id)

      assert Enum.find_index(job_ids, &(&1 == high.id)) <
               Enum.find_index(job_ids, &(&1 == low.id))
    end

    test "excludes jobs scheduled in the future" do
      future = DateTime.utc_now() |> DateTime.add(1, :hour)

      AI.enqueue("gender_guess", %{"name" => "future"}, scheduled_at: future)
      {:ok, now_job} = AI.enqueue("gender_guess", %{"name" => "now"})

      jobs = AI.list_runnable_jobs(10)
      job_ids = Enum.map(jobs, & &1.id)

      assert now_job.id in job_ids
      # The future job should not be in the list
      assert length(jobs) == 1
    end
  end

  describe "mark_running/1" do
    test "increments attempt and sets status to running" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      assert {:ok, running} = AI.mark_running(job)
      assert running.status == "running"
      assert running.attempt == 1
    end
  end

  describe "mark_completed/2" do
    test "sets status to completed with result" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, running} = AI.mark_running(job)

      assert {:ok, completed} =
               AI.mark_completed(running, %{
                 result: %{"gender" => "female"},
                 duration_ms: 500
               })

      assert completed.status == "completed"
      assert completed.result == %{"gender" => "female"}
      assert completed.duration_ms == 500
    end
  end

  describe "mark_failed/3" do
    test "schedules retry when under max_attempts" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"}, max_attempts: 5)
      {:ok, running} = AI.mark_running(job)

      assert {:ok, failed} = AI.mark_failed(running, "test error")
      assert failed.status == "scheduled"
      assert failed.error == "test error"
      assert failed.scheduled_at != nil
    end

    test "marks as failed when at max_attempts" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"}, max_attempts: 1)
      {:ok, running} = AI.mark_running(job)

      assert {:ok, failed} = AI.mark_failed(running, "test error")
      assert failed.status == "failed"
    end
  end

  describe "has_pending_job?/3" do
    test "returns true when a pending job exists for the subject" do
      photo_id = Ecto.UUID.generate()

      AI.enqueue("photo_description", %{"photo_id" => photo_id},
        subject_type: "Photo",
        subject_id: photo_id
      )

      assert AI.has_pending_job?("photo_description", "Photo", photo_id)
    end

    test "returns false when no pending job exists" do
      refute AI.has_pending_job?("photo_description", "Photo", Ecto.UUID.generate())
    end
  end

  describe "enqueue_all_photo_descriptions/1" do
    import Animina.PhotosFixtures

    test "enqueues jobs for all approved photos" do
      photo1 = approved_photo_fixture()
      photo2 = approved_photo_fixture()

      {enqueued, skipped} = AI.enqueue_all_photo_descriptions()

      assert enqueued == 2
      assert skipped == 0

      assert AI.has_pending_job?("photo_description", "Photo", photo1.id)
      assert AI.has_pending_job?("photo_description", "Photo", photo2.id)
    end

    test "skips photos that already have a pending job" do
      photo1 = approved_photo_fixture()
      photo2 = approved_photo_fixture()

      # Pre-enqueue a job for photo1
      AI.enqueue("photo_description", %{"photo_id" => photo1.id},
        subject_type: "Photo",
        subject_id: photo1.id
      )

      {enqueued, skipped} = AI.enqueue_all_photo_descriptions()

      assert enqueued == 1
      assert skipped == 1

      # photo2 should have gotten a new job
      assert AI.has_pending_job?("photo_description", "Photo", photo2.id)
    end

    test "uses background priority (5) by default" do
      approved_photo_fixture()

      {1, 0} = AI.enqueue_all_photo_descriptions()

      result = AI.list_jobs(filter_job_type: "photo_description")
      job = hd(result.entries)
      assert job.priority == 5
    end

    test "ignores non-approved photos" do
      # Create a pending photo (not approved)
      _pending = photo_fixture(%{state: "pending"})
      approved = approved_photo_fixture()

      {enqueued, skipped} = AI.enqueue_all_photo_descriptions()

      assert enqueued == 1
      assert skipped == 0
      assert AI.has_pending_job?("photo_description", "Photo", approved.id)
    end
  end
end
