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
      assert job.max_attempts == 10
      assert job.status == "pending"
      assert job.attempt == 0
    end

    test "creates a job with correct defaults for gender_guess" do
      assert {:ok, job} = AI.enqueue("gender_guess", %{"name" => "alice"})

      assert job.job_type == "gender_guess"
      assert job.priority == 1
      assert job.max_attempts == 1
    end

    test "creates a job with correct defaults for wingman_suggestion" do
      assert {:ok, job} =
               AI.enqueue("wingman_suggestion", %{
                 "prompt" => "test prompt",
                 "conversation_id" => Ecto.UUID.generate(),
                 "user_id" => Ecto.UUID.generate(),
                 "context_hash" => "abc123"
               })

      assert job.job_type == "wingman_suggestion"
      assert job.priority == 2
      assert job.max_attempts == 1
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

  describe "force_cancel/1" do
    test "cancels a running job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, running} = AI.mark_running(job)

      assert {:ok, cancelled} = AI.force_cancel(running.id)
      assert cancelled.status == "cancelled"
      assert cancelled.error =~ "Force cancelled by admin"
    end

    test "rejects non-running job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      assert {:error, :not_cancellable} = AI.force_cancel(job.id)
    end

    test "returns not_found for missing job" do
      assert {:error, :not_found} = AI.force_cancel(Ecto.UUID.generate())
    end
  end

  describe "force_restart/1" do
    test "resets a running job to pending" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, running} = AI.mark_running(job)

      assert {:ok, restarted} = AI.force_restart(running.id)
      assert restarted.status == "pending"
      assert is_nil(restarted.scheduled_at)
    end

    test "rejects non-running job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      assert {:error, :not_restartable} = AI.force_restart(job.id)
    end

    test "returns not_found for missing job" do
      assert {:error, :not_found} = AI.force_restart(Ecto.UUID.generate())
    end
  end

  describe "conditional mark_completed/2" do
    test "does not overwrite a cancelled job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, running} = AI.mark_running(job)

      # Admin cancels while job is "running" — simulate race
      {:ok, _} = AI.force_cancel(running.id)

      # Executor tries to mark completed with stale struct
      assert {:error, :job_not_running} =
               AI.mark_completed(running, %{result: %{"gender" => "female"}, duration_ms: 100})
    end
  end

  describe "conditional mark_failed/3" do
    test "does not overwrite a cancelled job" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"}, max_attempts: 1)
      {:ok, running} = AI.mark_running(job)

      # Admin cancels while job is "running"
      {:ok, _} = AI.force_cancel(running.id)

      # Executor tries to mark failed with stale struct
      assert {:error, :job_not_running} = AI.mark_failed(running, "some error")
    end
  end

  describe "reset_stuck_jobs/1" do
    test "resets jobs running longer than timeout" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, _running} = AI.mark_running(job)

      # Backdate updated_at to simulate stuck job (5 minutes ago)
      Repo.update_all(
        from(j in Job, where: j.id == ^job.id),
        set: [updated_at: DateTime.utc_now() |> DateTime.add(-300, :second)]
      )

      count = AI.reset_stuck_jobs(180)
      assert count == 1

      updated = AI.get_job(job.id)
      assert updated.status == "scheduled"
      assert updated.error =~ "stuck"
    end

    test "leaves recently started jobs alone" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, _running} = AI.mark_running(job)

      count = AI.reset_stuck_jobs(180)
      assert count == 0

      updated = AI.get_job(job.id)
      assert updated.status == "running"
    end

    test "only auto-resets a stuck job once" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})
      {:ok, _running} = AI.mark_running(job)

      # Backdate to simulate stuck
      Repo.update_all(
        from(j in Job, where: j.id == ^job.id),
        set: [updated_at: DateTime.utc_now() |> DateTime.add(-300, :second)]
      )

      # First reset works
      assert AI.reset_stuck_jobs(180) == 1
      updated = AI.get_job(job.id)
      assert updated.status == "scheduled"

      # Simulate it getting picked up and running again, then getting stuck again
      updated
      |> Job.update_changeset(%{status: "running"})
      |> Repo.update!()

      Repo.update_all(
        from(j in Job, where: j.id == ^job.id),
        set: [updated_at: DateTime.utc_now() |> DateTime.add(-300, :second)]
      )

      # Second reset should NOT pick it up (already has stuck error)
      assert AI.reset_stuck_jobs(180) == 0
    end
  end

  describe "reschedule_running_job/1" do
    test "resets a running job to scheduled without incrementing attempt" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"}, max_attempts: 3)
      {:ok, running} = AI.mark_running(job)

      assert running.attempt == 1
      assert running.status == "running"

      assert {1, _} = AI.reschedule_running_job(running.id)

      updated = AI.get_job(job.id)
      assert updated.status == "scheduled"
      # Attempt stays at 1 — not incremented
      assert updated.attempt == 1
      assert updated.scheduled_at != nil
    end

    test "does not affect non-running jobs" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      assert {0, _} = AI.reschedule_running_job(job.id)

      updated = AI.get_job(job.id)
      assert updated.status == "pending"
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

  describe "has_high_priority_demand?/0" do
    test "returns true when a high-priority job is pending" do
      AI.enqueue("gender_guess", %{"name" => "alice"})

      assert AI.has_high_priority_demand?()
    end

    test "returns false when only low-priority jobs are pending" do
      AI.enqueue("photo_description", %{"photo_id" => Ecto.UUID.generate()})

      refute AI.has_high_priority_demand?()
    end

    test "returns false when high-priority jobs are scheduled in the future" do
      future = DateTime.utc_now() |> DateTime.add(1, :hour)
      AI.enqueue("gender_guess", %{"name" => "alice"}, scheduled_at: future)

      refute AI.has_high_priority_demand?()
    end

    test "returns false when no jobs exist" do
      refute AI.has_high_priority_demand?()
    end
  end

  describe "high_priority_job_count/0" do
    test "counts pending/scheduled/running prio 1+2 jobs" do
      # prio 1 — counted
      AI.enqueue("gender_guess", %{"name" => "alice"})
      # prio 2 — counted
      AI.enqueue("wingman_suggestion", %{
        "prompt" => "p",
        "conversation_id" => Ecto.UUID.generate(),
        "user_id" => Ecto.UUID.generate(),
        "context_hash" => "h"
      })

      # prio 4 — NOT counted
      AI.enqueue("photo_description", %{"photo_id" => Ecto.UUID.generate()})

      assert AI.high_priority_job_count() == 2
    end

    test "excludes future-scheduled jobs" do
      future = DateTime.utc_now() |> DateTime.add(1, :hour)
      AI.enqueue("gender_guess", %{"name" => "bob"}, scheduled_at: future)

      assert AI.high_priority_job_count() == 0
    end

    test "includes running jobs" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "carol"})
      {:ok, _running} = AI.mark_running(job)

      assert AI.high_priority_job_count() == 1
    end
  end

  describe "cancel_expired_jobs/0" do
    test "cancels expired pending jobs" do
      expired_at = DateTime.utc_now() |> DateTime.add(-10, :second)

      {:ok, job} =
        AI.enqueue("gender_guess", %{"name" => "test"}, expires_at: expired_at)

      assert AI.cancel_expired_jobs() >= 1

      updated = AI.get_job(job.id)
      assert updated.status == "cancelled"
      assert updated.error == "Expired"
    end

    test "skips jobs without expires_at" do
      {:ok, job} = AI.enqueue("gender_guess", %{"name" => "test"})

      AI.cancel_expired_jobs()

      updated = AI.get_job(job.id)
      assert updated.status == "pending"
    end

    test "skips running jobs" do
      expired_at = DateTime.utc_now() |> DateTime.add(-10, :second)

      {:ok, job} =
        AI.enqueue("gender_guess", %{"name" => "test"}, expires_at: expired_at)

      {:ok, _running} = AI.mark_running(job)

      AI.cancel_expired_jobs()

      updated = AI.get_job(job.id)
      assert updated.status == "running"
    end

    test "skips jobs not yet expired" do
      future = DateTime.utc_now() |> DateTime.add(60, :second)

      {:ok, job} =
        AI.enqueue("gender_guess", %{"name" => "test"}, expires_at: future)

      AI.cancel_expired_jobs()

      updated = AI.get_job(job.id)
      assert updated.status == "pending"
    end
  end

  describe "list_runnable_jobs/1 with expiry" do
    test "excludes expired jobs" do
      expired_at = DateTime.utc_now() |> DateTime.add(-10, :second)

      {:ok, expired_job} =
        AI.enqueue("gender_guess", %{"name" => "expired"}, expires_at: expired_at)

      {:ok, valid_job} = AI.enqueue("gender_guess", %{"name" => "valid"})

      jobs = AI.list_runnable_jobs(10)
      job_ids = Enum.map(jobs, & &1.id)

      refute expired_job.id in job_ids
      assert valid_job.id in job_ids
    end

    test "includes jobs with future expires_at" do
      future = DateTime.utc_now() |> DateTime.add(60, :second)

      {:ok, job} =
        AI.enqueue("gender_guess", %{"name" => "future"}, expires_at: future)

      jobs = AI.list_runnable_jobs(10)
      job_ids = Enum.map(jobs, & &1.id)

      assert job.id in job_ids
    end
  end

  describe "enqueue/3 with expires_at" do
    test "stores expires_at on the job" do
      expires_at = DateTime.utc_now() |> DateTime.add(30, :second) |> DateTime.truncate(:second)

      {:ok, job} =
        AI.enqueue("gender_guess", %{"name" => "test"}, expires_at: expires_at)

      assert job.expires_at == expires_at
    end
  end
end
