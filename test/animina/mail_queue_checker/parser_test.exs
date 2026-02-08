defmodule Animina.MailQueueChecker.ParserTest do
  use ExUnit.Case, async: true

  alias Animina.MailQueueChecker.Parser

  describe "parse/1" do
    test "returns empty list for empty queue" do
      output = "Mail queue is empty\n"
      assert Parser.parse(output) == []
    end

    test "parses a single deferred entry" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF*    1234 Sun Feb  2 10:30:00  sender@example.com
      (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                               user@t-online.de
      -- 1 Kbytes in 1 Request.
      """

      result = Parser.parse(output)
      assert length(result) == 1

      entry = hd(result)
      assert entry.queue_id == "ABC123DEF"
      assert entry.recipient == "user@t-online.de"
      assert entry.reason =~ "Connection refused"
    end

    test "parses multiple entries" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF*    1234 Sun Feb  2 10:30:00  sender@example.com
      (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                               user@t-online.de

      GHI789JKL     5678 Mon Feb  3 14:15:00  other@example.com
      (host mx.gmx.net[212.227.17.168] said: 550 5.1.1 Requested action not taken: mailbox unavailable)
                                               somebody@gmx.de
      -- 6 Kbytes in 2 Requests.
      """

      result = Parser.parse(output)
      assert length(result) == 2

      [first, second] = result
      assert first.queue_id == "ABC123DEF"
      assert first.recipient == "user@t-online.de"
      assert second.queue_id == "GHI789JKL"
      assert second.recipient == "somebody@gmx.de"
    end

    test "strips active delivery marker (*) from queue ID" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF*    1234 Sun Feb  2 10:30:00  sender@example.com
      (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                               user@t-online.de
      -- 1 Kbytes in 1 Request.
      """

      [entry] = Parser.parse(output)
      assert entry.queue_id == "ABC123DEF"
    end

    test "handles entry without active marker" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF     1234 Sun Feb  2 10:30:00  sender@example.com
      (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                               user@t-online.de
      -- 1 Kbytes in 1 Request.
      """

      [entry] = Parser.parse(output)
      assert entry.queue_id == "ABC123DEF"
    end

    test "downcases recipient email" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF     1234 Sun Feb  2 10:30:00  sender@example.com
      (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                               User@T-Online.DE
      -- 1 Kbytes in 1 Request.
      """

      [entry] = Parser.parse(output)
      assert entry.recipient == "user@t-online.de"
    end

    test "handles multi-line error reason" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF     1234 Sun Feb  2 10:30:00  sender@example.com
      (host mx.t-online.de[194.25.134.8] said: 421 mta-out1.t-online.de
          Service not available - too many connections from your IP)
                                               user@t-online.de
      -- 1 Kbytes in 1 Request.
      """

      [entry] = Parser.parse(output)
      assert entry.reason =~ "Service not available"
      assert entry.reason =~ "too many connections"
    end

    test "parses arrival time" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF     1234 Sun Feb  2 10:30:00  sender@example.com
      (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                               user@t-online.de
      -- 1 Kbytes in 1 Request.
      """

      [entry] = Parser.parse(output)
      assert entry.arrived_at == "Sun Feb  2 10:30:00"
    end

    test "handles bang (!) marker for entries on hold" do
      output = """
      -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
      ABC123DEF!    1234 Sun Feb  2 10:30:00  sender@example.com
      (connect to mx.t-online.de[194.25.134.8]:25: Connection refused)
                                               user@t-online.de
      -- 1 Kbytes in 1 Request.
      """

      [entry] = Parser.parse(output)
      assert entry.queue_id == "ABC123DEF"
    end

    test "returns empty list for nil input" do
      assert Parser.parse(nil) == []
    end

    test "returns empty list for empty string" do
      assert Parser.parse("") == []
    end
  end
end
