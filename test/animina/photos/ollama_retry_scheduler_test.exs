defmodule Animina.Photos.OllamaRetrySchedulerTest do
  use Animina.DataCase, async: true

  alias Animina.Photos
  alias Animina.Photos.OllamaRetryScheduler
  alias Animina.Repo
  alias Ecto.Adapters.SQL.Sandbox

  import Animina.PhotosFixtures

  # Helper to create a photo in ollama_checking state
  defp ollama_checking_photo(user_id) do
    photo = photo_fixture(%{owner_id: user_id})

    photo
    |> Ecto.Changeset.change(%{state: "ollama_checking", width: 800, height: 600})
    |> Repo.update!()
  end

  describe "backoff calculation" do
    test "calculate_next_retry_at/1 uses 15 * retry_count minutes formula" do
      # For retry_count = 1: 15 minutes
      result_1 = Photos.calculate_next_retry_at(1)
      now = DateTime.utc_now()
      diff_1 = DateTime.diff(result_1, now, :minute)
      assert diff_1 >= 14 and diff_1 <= 16

      # For retry_count = 5: 75 minutes
      result_5 = Photos.calculate_next_retry_at(5)
      diff_5 = DateTime.diff(result_5, now, :minute)
      assert diff_5 >= 74 and diff_5 <= 76

      # For retry_count = 20: 300 minutes (5 hours)
      result_20 = Photos.calculate_next_retry_at(20)
      diff_20 = DateTime.diff(result_20, now, :minute)
      assert diff_20 >= 299 and diff_20 <= 301
    end

    test "backoff intervals sum to approximately 48 hours for 20 attempts" do
      # Sum of 15*(1+2+3+...+20) = 15 * (20*21/2) = 15 * 210 = 3150 minutes
      # 3150 / 60 = 52.5 hours, which is ~2 days
      total_minutes = Enum.reduce(1..20, 0, fn n, acc -> acc + 15 * n end)
      total_hours = total_minutes / 60
      assert total_hours > 48 and total_hours < 60
    end
  end

  describe "queue_for_ollama_retry/2" do
    setup do
      user = Animina.AccountsFixtures.user_fixture()
      photo = ollama_checking_photo(user.id)
      %{user: user, photo: photo}
    end

    test "queues photo for retry with correct fields", %{photo: photo} do
      assert {:ok, updated} = Photos.queue_for_ollama_retry(photo)

      assert updated.state == "pending_ollama"
      assert updated.ollama_retry_count == 1
      assert updated.ollama_retry_at != nil
    end

    test "increments retry count on subsequent retries", %{photo: photo} do
      # First retry
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)
      assert photo.ollama_retry_count == 1

      # Return to checking state (simulating retry)
      {:ok, photo} = Photos.return_to_ollama_checking(photo)

      # Second retry
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)
      assert photo.ollama_retry_count == 2
    end

    test "transitions to needs_manual_review after 20 retries", %{photo: photo} do
      # Set retry count to 20 (max)
      {:ok, photo} =
        photo
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Repo.update()

      {:ok, updated} = Photos.queue_for_ollama_retry(photo)

      assert updated.state == "needs_manual_review"
      assert updated.ollama_retry_count == 21
      assert updated.ollama_retry_at == nil
    end
  end

  describe "return_to_ollama_checking/1" do
    setup do
      user = Animina.AccountsFixtures.user_fixture()
      photo = ollama_checking_photo(user.id)
      %{user: user, photo: photo}
    end

    test "transitions pending_ollama back to ollama_checking", %{photo: photo} do
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)
      assert photo.state == "pending_ollama"

      {:ok, updated} = Photos.return_to_ollama_checking(photo)
      assert updated.state == "ollama_checking"
    end

    test "returns error for invalid states", %{photo: photo} do
      # Photo is in ollama_checking, not pending_ollama
      assert {:error, :invalid_state} = Photos.return_to_ollama_checking(photo)
    end
  end

  describe "list_photos_due_for_ollama_retry/1" do
    setup do
      user = Animina.AccountsFixtures.user_fixture()
      %{user: user}
    end

    test "returns photos with ollama_retry_at <= now", %{user: user} do
      # Create a photo due for retry (past time)
      photo1 = ollama_checking_photo(user.id)
      {:ok, photo1} = Photos.queue_for_ollama_retry(photo1)

      {:ok, photo1} =
        photo1
        |> Ecto.Changeset.change(%{
          ollama_retry_at:
            DateTime.utc_now() |> DateTime.add(-1, :minute) |> DateTime.truncate(:second)
        })
        |> Repo.update()

      # Create a photo not yet due (future time)
      photo2 = ollama_checking_photo(user.id)
      {:ok, _photo2} = Photos.queue_for_ollama_retry(photo2)

      due_photos = Photos.list_photos_due_for_ollama_retry()

      assert length(due_photos) == 1
      assert hd(due_photos).id == photo1.id
    end

    test "excludes photos in needs_manual_review state", %{user: user} do
      photo = ollama_checking_photo(user.id)

      {:ok, photo} =
        photo
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Repo.update()

      # This will transition to needs_manual_review
      {:ok, _photo} = Photos.queue_for_ollama_retry(photo)

      due_photos = Photos.list_photos_due_for_ollama_retry()
      assert Enum.empty?(due_photos)
    end
  end

  describe "count_ollama_queue/1" do
    setup do
      user = Animina.AccountsFixtures.user_fixture()
      %{user: user}
    end

    test "counts all photos in queue states", %{user: user} do
      # Create photos in queue state
      photo1 = ollama_checking_photo(user.id)
      {:ok, _} = Photos.queue_for_ollama_retry(photo1)

      photo2 = ollama_checking_photo(user.id)
      {:ok, _} = Photos.queue_for_ollama_retry(photo2)

      photo3 = ollama_checking_photo(user.id)

      {:ok, photo3} =
        photo3
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Repo.update()

      {:ok, _} = Photos.queue_for_ollama_retry(photo3)

      assert Photos.count_ollama_queue() == 3
    end

    test "filters by state when specified", %{user: user} do
      photo1 = ollama_checking_photo(user.id)
      {:ok, _} = Photos.queue_for_ollama_retry(photo1)

      photo2 = ollama_checking_photo(user.id)

      {:ok, photo2} =
        photo2
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Repo.update()

      {:ok, _} = Photos.queue_for_ollama_retry(photo2)

      assert Photos.count_ollama_queue(state_filter: "pending_ollama") == 1
      assert Photos.count_ollama_queue(state_filter: "needs_manual_review") == 1
    end
  end

  describe "admin actions" do
    setup do
      user = Animina.AccountsFixtures.user_fixture()
      admin = Animina.AccountsFixtures.user_fixture()
      Animina.Accounts.assign_role(admin, "admin")
      photo = ollama_checking_photo(user.id)
      %{user: user, admin: admin, photo: photo}
    end

    test "approve_from_ollama_queue/2 approves and clears retry fields", %{
      photo: photo,
      admin: admin
    } do
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)
      assert photo.state == "pending_ollama"

      {:ok, updated} = Photos.approve_from_ollama_queue(photo, admin)

      assert updated.state == "approved"
      assert updated.ollama_retry_count == 0
      assert updated.ollama_retry_at == nil
      assert updated.ollama_check_type == nil
    end

    test "reject_from_ollama_queue/3 rejects and clears retry fields", %{
      photo: photo,
      admin: admin
    } do
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)

      {:ok, updated} = Photos.reject_from_ollama_queue(photo, admin)

      assert updated.state == "error"
      assert updated.ollama_retry_count == 0
      assert updated.error_message == "Rejected by admin"
    end

    test "retry_from_manual_review/2 resets retry and queues", %{photo: photo, admin: admin} do
      {:ok, photo} =
        photo
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Repo.update()

      {:ok, photo} = Photos.queue_for_ollama_retry(photo)
      assert photo.state == "needs_manual_review"

      {:ok, updated} = Photos.retry_from_manual_review(photo, admin)

      assert updated.state == "pending_ollama"
      assert updated.ollama_retry_count == 0
      assert updated.ollama_retry_at != nil
    end
  end

  describe "scheduler get_stats/0" do
    test "returns scheduler statistics" do
      # Start the scheduler with a unique name to avoid conflicts
      name = :"test_scheduler_#{System.unique_integer([:positive])}"

      {:ok, pid} =
        OllamaRetryScheduler.start_link(
          name: name,
          poll_interval_ms: 60_000
        )

      # Allow the scheduler process to access the database in tests
      Sandbox.allow(Repo, self(), pid)

      stats = OllamaRetryScheduler.get_stats(name)

      assert Map.has_key?(stats, :queue_count)
      assert Map.has_key?(stats, :total_processed)
      assert Map.has_key?(stats, :total_succeeded)
      assert Map.has_key?(stats, :total_failed)

      GenServer.stop(pid)
    end
  end
end
