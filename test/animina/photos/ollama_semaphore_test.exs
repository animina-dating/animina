defmodule Animina.Photos.OllamaSemaphoreTest do
  use ExUnit.Case, async: true

  alias Animina.Photos.OllamaSemaphore

  setup do
    # Start a fresh semaphore per test with max=2
    name = :"semaphore_#{:erlang.unique_integer([:positive])}"
    start_supervised!({OllamaSemaphore, name: name, max: 2})
    %{server: name}
  end

  describe "acquire/2" do
    test "grants permit when under limit", %{server: server} do
      assert :ok = OllamaSemaphore.acquire(5_000, server)

      status = OllamaSemaphore.status(server)
      assert status.active == 1
      assert status.max == 2
      assert status.waiting == 0
    end

    test "grants multiple permits up to limit", %{server: server} do
      assert :ok = OllamaSemaphore.acquire(5_000, server)
      assert :ok = OllamaSemaphore.acquire(5_000, server)

      status = OllamaSemaphore.status(server)
      assert status.active == 2
    end

    test "blocks at limit and unblocks on release", %{server: server} do
      # Fill both slots
      assert :ok = OllamaSemaphore.acquire(5_000, server)
      assert :ok = OllamaSemaphore.acquire(5_000, server)

      # Third acquire should block until we release
      test_pid = self()

      task =
        Task.async(fn ->
          send(test_pid, :waiting)
          result = OllamaSemaphore.acquire(5_000, server)
          send(test_pid, {:acquired, result})
          result
        end)

      # Wait for the task to start waiting
      assert_receive :waiting, 1_000

      # Give it a moment to actually enqueue
      Process.sleep(50)

      status = OllamaSemaphore.status(server)
      assert status.waiting == 1

      # Release a slot
      OllamaSemaphore.release(server)

      # The blocked task should now acquire
      assert_receive {:acquired, :ok}, 2_000
      Task.await(task)
    end

    test "returns error on timeout", %{server: server} do
      # Fill both slots
      assert :ok = OllamaSemaphore.acquire(5_000, server)
      assert :ok = OllamaSemaphore.acquire(5_000, server)

      # Third acquire with very short timeout
      assert {:error, :timeout} = OllamaSemaphore.acquire(50, server)

      # Waiter should be cleaned up
      Process.sleep(10)
      status = OllamaSemaphore.status(server)
      assert status.waiting == 0
    end
  end

  describe "release/1" do
    test "decrements active count", %{server: server} do
      assert :ok = OllamaSemaphore.acquire(5_000, server)
      assert %{active: 1} = OllamaSemaphore.status(server)

      OllamaSemaphore.release(server)
      Process.sleep(10)
      assert %{active: 0} = OllamaSemaphore.status(server)
    end

    test "does not go below zero", %{server: server} do
      OllamaSemaphore.release(server)
      Process.sleep(10)
      assert %{active: 0} = OllamaSemaphore.status(server)
    end
  end

  describe "status/1" do
    test "returns correct counts", %{server: server} do
      status = OllamaSemaphore.status(server)
      assert status == %{active: 0, max: 2, waiting: 0}
    end
  end

  describe "dead waiter cleanup" do
    test "removes dead waiter from queue", %{server: server} do
      # Fill both slots
      assert :ok = OllamaSemaphore.acquire(5_000, server)
      assert :ok = OllamaSemaphore.acquire(5_000, server)

      # Spawn a process that will wait, then kill it
      {pid, ref} =
        spawn_monitor(fn ->
          OllamaSemaphore.acquire(60_000, server)
        end)

      # Wait for it to enqueue
      Process.sleep(50)
      assert %{waiting: 1} = OllamaSemaphore.status(server)

      # Kill the waiting process
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      # Give the semaphore time to process the DOWN message
      Process.sleep(50)
      assert %{waiting: 0} = OllamaSemaphore.status(server)
    end
  end
end
