defmodule Animina.TimeMachineTest do
  use ExUnit.Case, async: true

  alias Animina.TimeMachine

  describe "utc_now/0 (test env passthrough)" do
    test "returns a DateTime close to real DateTime.utc_now()" do
      real_now = DateTime.utc_now()
      tm_now = TimeMachine.utc_now()

      # Should be within 1 second of each other
      assert abs(DateTime.diff(tm_now, real_now, :millisecond)) < 1_000
    end
  end

  describe "utc_now/1 (test env passthrough)" do
    test "returns a DateTime truncated to the given precision" do
      tm_now = TimeMachine.utc_now(:second)

      # Microsecond should be 0 when truncated to :second
      assert tm_now.microsecond == {0, 0}
    end
  end

  describe "utc_today/0 (test env passthrough)" do
    test "returns today's date" do
      assert TimeMachine.utc_today() == Date.utc_today()
    end
  end

  describe "format_offset/0 (test env passthrough)" do
    test "returns nil (no offset in test)" do
      assert TimeMachine.format_offset() == nil
    end
  end

  describe "virtual_now/0 (test env passthrough)" do
    test "returns a formatted string" do
      result = TimeMachine.virtual_now()
      assert is_binary(result)
    end
  end

  describe "mutation functions are no-ops in test" do
    test "add_hours/1 returns :ok" do
      assert TimeMachine.add_hours(1) == :ok
    end

    test "add_days/1 returns :ok" do
      assert TimeMachine.add_days(1) == :ok
    end

    test "reset/0 returns :ok" do
      assert TimeMachine.reset() == :ok
    end
  end
end
