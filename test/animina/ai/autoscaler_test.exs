defmodule Animina.AI.AutoscalerTest do
  use ExUnit.Case, async: true

  alias Animina.AI.Autoscaler

  setup do
    # Start a test semaphore
    {:ok, semaphore} =
      Animina.AI.Semaphore.start_link(name: :"test_semaphore_#{System.unique_integer()}", max: 2)

    {:ok, autoscaler} =
      Autoscaler.start_link(
        name: :"test_autoscaler_#{System.unique_integer()}",
        min_slots: 2,
        max_slots: 5,
        up_threshold_ms: 5_000,
        down_threshold_ms: 20_000,
        cooldown_ms: 0,
        window_size: 5,
        initial_max: 2,
        semaphore: semaphore
      )

    {:ok, autoscaler: autoscaler, semaphore: semaphore}
  end

  test "starts with initial state", %{autoscaler: autoscaler} do
    state = Autoscaler.get_state(autoscaler)
    assert state.current_max == 2
    assert state.min_slots == 2
    assert state.max_slots == 5
    assert state.window_size == 0
  end

  test "scales up when response times are fast", %{autoscaler: autoscaler, semaphore: semaphore} do
    # Report fast response times
    for _ <- 1..5, do: Autoscaler.report_duration(2_000, autoscaler)

    # Give GenServer time to process
    Process.sleep(50)

    state = Autoscaler.get_state(autoscaler)
    assert state.current_max > 2

    # Verify semaphore was updated
    sem_status = Animina.AI.Semaphore.status(semaphore)
    assert sem_status.max == state.current_max
  end

  test "scales down when response times are slow", %{autoscaler: autoscaler} do
    # First scale up
    for _ <- 1..5, do: Autoscaler.report_duration(2_000, autoscaler)
    Process.sleep(50)

    state = Autoscaler.get_state(autoscaler)
    assert state.current_max > 2

    # Now report slow times
    for _ <- 1..5, do: Autoscaler.report_duration(25_000, autoscaler)
    Process.sleep(50)

    new_state = Autoscaler.get_state(autoscaler)
    assert new_state.current_max < state.current_max
  end

  test "does not scale below min_slots", %{autoscaler: autoscaler} do
    # Report very slow times
    for _ <- 1..10, do: Autoscaler.report_duration(30_000, autoscaler)
    Process.sleep(50)

    state = Autoscaler.get_state(autoscaler)
    assert state.current_max >= 2
  end
end
