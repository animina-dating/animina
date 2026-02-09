defmodule Animina.MailQueueCheckerTest do
  use ExUnit.Case, async: true

  alias Animina.MailQueueChecker

  @sample_mailq_output """
  -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
  ABC123DEF     1234 Sun Feb  2 10:30:00  sender@example.com
  (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                           user@t-online.de
  -- 1 Kbytes in 1 Request.
  """

  describe "GenServer with injected cmd_fn" do
    setup do
      # Use a unique ETS table name per test to avoid conflicts
      table_name = :"mail_queue_failures_#{System.unique_integer([:positive])}"

      cmd_fn = fn "mailq", [] ->
        {@sample_mailq_output, 0}
      end

      {:ok, pid} =
        MailQueueChecker.start_link(
          cmd_fn: cmd_fn,
          table_name: table_name,
          interval: :timer.minutes(10),
          name: :"checker_#{System.unique_integer([:positive])}"
        )

      %{pid: pid, table_name: table_name}
    end

    test "populates ETS after initial check", %{table_name: table_name} do
      # Give the GenServer a moment to run the initial check
      Process.sleep(100)

      result = :ets.lookup(table_name, "user@t-online.de")
      assert [{_, entry}] = result
      assert entry.queue_id == "ABC123DEF"
      assert entry.reason =~ "Connection refused"
    end

    test "lookup returns entry for known email", %{pid: pid} do
      Process.sleep(100)

      state = :sys.get_state(pid)
      result = MailQueueChecker.lookup("user@t-online.de", state.table_name)
      assert result != nil
      assert result.queue_id == "ABC123DEF"
    end

    test "lookup returns nil for unknown email", %{pid: pid} do
      Process.sleep(100)

      state = :sys.get_state(pid)
      result = MailQueueChecker.lookup("unknown@example.com", state.table_name)
      assert result == nil
    end
  end

  describe "PubSub broadcast" do
    test "broadcasts for newly detected failures" do
      table_name = :"mail_queue_failures_#{System.unique_integer([:positive])}"
      email = "user@t-online.de"

      # Subscribe before starting
      Phoenix.PubSub.subscribe(Animina.PubSub, MailQueueChecker.topic(email))

      cmd_fn = fn "mailq", [] ->
        {@sample_mailq_output, 0}
      end

      {:ok, _pid} =
        MailQueueChecker.start_link(
          cmd_fn: cmd_fn,
          table_name: table_name,
          interval: :timer.minutes(10),
          name: :"checker_#{System.unique_integer([:positive])}"
        )

      assert_receive {:mail_delivery_failure, entry}, 1000
      assert entry.recipient == email
      assert entry.reason =~ "Connection refused"
    end

    test "does not re-broadcast for already known failures" do
      table_name = :"mail_queue_failures_#{System.unique_integer([:positive])}"
      email = "user@t-online.de"

      call_count = :counters.new(1, [:atomics])

      cmd_fn = fn "mailq", [] ->
        :counters.add(call_count, 1, 1)
        {@sample_mailq_output, 0}
      end

      Phoenix.PubSub.subscribe(Animina.PubSub, MailQueueChecker.topic(email))

      {:ok, pid} =
        MailQueueChecker.start_link(
          cmd_fn: cmd_fn,
          table_name: table_name,
          interval: 50,
          name: :"checker_#{System.unique_integer([:positive])}"
        )

      # First broadcast
      assert_receive {:mail_delivery_failure, _entry}, 1000

      # Wait for at least 2 more ticks
      Process.sleep(200)

      # Should NOT have received another broadcast
      refute_receive {:mail_delivery_failure, _}

      # But the cmd_fn was called multiple times
      assert :counters.get(call_count, 1) >= 2

      GenServer.stop(pid)
    end
  end

  describe "topic/1" do
    test "returns correct topic string" do
      assert MailQueueChecker.topic("user@example.com") ==
               "mail_queue:delivery_failure:user@example.com"
    end
  end

  describe "lookup/1 without running GenServer" do
    test "returns nil when ETS table does not exist" do
      assert MailQueueChecker.lookup("anyone@example.com") == nil
    end
  end
end
