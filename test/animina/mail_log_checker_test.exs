defmodule Animina.MailLogCheckerTest do
  use ExUnit.Case, async: true

  alias Animina.MailLogChecker

  @bounce_content "Feb  2 12:34:56 mail postfix/smtp[12345]: ABC123DEF: to=<user@example.com>, relay=mx.example.com[1.2.3.4]:25, dsn=5.1.1, status=bounced (host mx.example.com said: 550 unrouteable mail domain example.com)"

  describe "GenServer with injected read_fn" do
    setup do
      table_name = :"mail_log_bounces_#{System.unique_integer([:positive])}"

      content = @bounce_content

      read_fn = fn _path, _pos ->
        {:ok, content, byte_size(content)}
      end

      update_fn = fn _entry, :broadcast -> :ok end

      {:ok, pid} =
        MailLogChecker.start_link(
          read_fn: read_fn,
          update_fn: update_fn,
          table_name: table_name,
          interval: :timer.minutes(10),
          name: :"log_checker_#{System.unique_integer([:positive])}"
        )

      %{pid: pid, table_name: table_name}
    end

    test "populates ETS after initial check", %{table_name: table_name} do
      Process.sleep(100)

      result = :ets.lookup(table_name, "user@example.com")
      assert [{_, entry}] = result
      assert entry.queue_id == "ABC123DEF"
      assert entry.reason =~ "550 unrouteable"
    end

    test "lookup returns entry for known email", %{table_name: table_name} do
      Process.sleep(100)

      result = MailLogChecker.lookup("user@example.com", table_name)
      assert result != nil
      assert result.queue_id == "ABC123DEF"
    end

    test "lookup returns nil for unknown email", %{table_name: table_name} do
      Process.sleep(100)

      result = MailLogChecker.lookup("unknown@example.com", table_name)
      assert result == nil
    end
  end

  describe "PubSub broadcast via update_fn" do
    test "update_fn is called for new bounces" do
      table_name = :"mail_log_bounces_#{System.unique_integer([:positive])}"
      test_pid = self()

      content = @bounce_content

      read_fn = fn _path, _pos ->
        {:ok, content, byte_size(content)}
      end

      update_fn = fn entry, :broadcast ->
        send(test_pid, {:bounce_detected, entry})
      end

      {:ok, _pid} =
        MailLogChecker.start_link(
          read_fn: read_fn,
          update_fn: update_fn,
          table_name: table_name,
          interval: :timer.minutes(10),
          name: :"log_checker_#{System.unique_integer([:positive])}"
        )

      assert_receive {:bounce_detected, entry}, 1000
      assert entry.recipient == "user@example.com"
      assert entry.reason =~ "550 unrouteable"
    end

    test "does not re-call update_fn for already known bounces" do
      table_name = :"mail_log_bounces_#{System.unique_integer([:positive])}"
      call_count = :counters.new(1, [:atomics])

      content = @bounce_content

      read_fn = fn _path, _pos ->
        {:ok, content, byte_size(content)}
      end

      update_fn = fn _entry, :broadcast ->
        :counters.add(call_count, 1, 1)
      end

      {:ok, pid} =
        MailLogChecker.start_link(
          read_fn: read_fn,
          update_fn: update_fn,
          table_name: table_name,
          interval: 50,
          name: :"log_checker_#{System.unique_integer([:positive])}"
        )

      # Wait for initial check + a couple more ticks
      Process.sleep(250)

      # Should only have been called once (first detection)
      assert :counters.get(call_count, 1) == 1

      GenServer.stop(pid)
    end
  end

  describe "log rotation handling" do
    test "resets position when file shrinks" do
      table_name = :"mail_log_bounces_#{System.unique_integer([:positive])}"
      call_count = :counters.new(1, [:atomics])

      content = @bounce_content

      read_fn = fn _path, pos ->
        if pos > 0 do
          # Simulate file shrunk (log rotation)
          {:error, :file_shrunk, 0}
        else
          :counters.add(call_count, 1, 1)
          {:ok, content, byte_size(content)}
        end
      end

      update_fn = fn _entry, :broadcast -> :ok end

      {:ok, pid} =
        MailLogChecker.start_link(
          read_fn: read_fn,
          update_fn: update_fn,
          table_name: table_name,
          interval: 50,
          name: :"log_checker_#{System.unique_integer([:positive])}"
        )

      Process.sleep(200)

      # read_fn should have been called with pos=0 at least twice
      # (once for initial check, once after rotation detection)
      assert :counters.get(call_count, 1) >= 2

      GenServer.stop(pid)
    end
  end

  describe "missing/empty file handling" do
    test "handles missing file gracefully" do
      table_name = :"mail_log_bounces_#{System.unique_integer([:positive])}"

      read_fn = fn _path, _pos ->
        {:error, :enoent}
      end

      update_fn = fn _entry, :broadcast -> :ok end

      {:ok, pid} =
        MailLogChecker.start_link(
          read_fn: read_fn,
          update_fn: update_fn,
          table_name: table_name,
          interval: :timer.minutes(10),
          name: :"log_checker_#{System.unique_integer([:positive])}"
        )

      Process.sleep(100)

      # Should not crash, ETS should be empty
      assert :ets.info(table_name, :size) == 0

      GenServer.stop(pid)
    end

    test "handles empty content gracefully" do
      table_name = :"mail_log_bounces_#{System.unique_integer([:positive])}"

      read_fn = fn _path, _pos ->
        {:ok, "", 0}
      end

      update_fn = fn _entry, :broadcast -> :ok end

      {:ok, pid} =
        MailLogChecker.start_link(
          read_fn: read_fn,
          update_fn: update_fn,
          table_name: table_name,
          interval: :timer.minutes(10),
          name: :"log_checker_#{System.unique_integer([:positive])}"
        )

      Process.sleep(100)

      assert :ets.info(table_name, :size) == 0

      GenServer.stop(pid)
    end
  end

  describe "lookup/1 without running GenServer" do
    test "returns nil when ETS table does not exist" do
      assert MailLogChecker.lookup("anyone@example.com") == nil
    end
  end
end
