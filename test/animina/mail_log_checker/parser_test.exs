defmodule Animina.MailLogChecker.ParserTest do
  use ExUnit.Case, async: true

  alias Animina.MailLogChecker.Parser

  @bounce_line "Feb  2 12:34:56 mail postfix/smtp[12345]: ABC123DEF: to=<user@example.com>, relay=mx.example.com[1.2.3.4]:25, delay=0.5, delays=0.1/0/0.2/0.2, dsn=5.1.1, status=bounced (host mx.example.com[1.2.3.4] said: 550 unrouteable mail domain example.com (in reply to RCPT TO command))"

  @sent_line "Feb  2 12:34:56 mail postfix/smtp[12345]: ABC123DEF: to=<user@example.com>, relay=mx.example.com[1.2.3.4]:25, delay=0.5, dsn=2.0.0, status=sent (250 OK)"

  @deferred_line "Feb  2 12:34:56 mail postfix/smtp[12345]: ABC123DEF: to=<user@example.com>, relay=none, delay=300, dsn=4.4.1, status=deferred (connect to mx.example.com[1.2.3.4]:25: Connection refused)"

  describe "parse/1" do
    test "extracts bounce entry from syslog line" do
      assert [entry] = Parser.parse(@bounce_line)
      assert entry.queue_id == "ABC123DEF"
      assert entry.recipient == "user@example.com"
      assert entry.reason =~ "550 unrouteable mail domain"
      assert entry.timestamp == "Feb  2 12:34:56"
    end

    test "ignores status=sent lines" do
      assert [] = Parser.parse(@sent_line)
    end

    test "ignores status=deferred lines" do
      assert [] = Parser.parse(@deferred_line)
    end

    test "returns empty list for nil" do
      assert [] = Parser.parse(nil)
    end

    test "returns empty list for empty string" do
      assert [] = Parser.parse("")
    end

    test "handles multiple bounce lines" do
      content = """
      Feb  2 12:34:56 mail postfix/smtp[12345]: AAAA1111: to=<alice@example.com>, relay=mx.example.com[1.2.3.4]:25, dsn=5.1.1, status=bounced (host mx.example.com said: 550 no such user)
      Feb  2 12:35:00 mail postfix/smtp[12345]: BBBB2222: to=<bob@example.com>, relay=mx.example.com[5.6.7.8]:25, dsn=5.1.1, status=bounced (host mx.example.com said: 550 user unknown)
      """

      entries = Parser.parse(content)
      assert length(entries) == 2
      assert Enum.at(entries, 0).recipient == "alice@example.com"
      assert Enum.at(entries, 1).recipient == "bob@example.com"
    end

    test "mixed lines — only extracts bounces" do
      content = """
      Feb  2 12:34:56 mail postfix/smtp[12345]: AAAA1111: to=<alice@example.com>, relay=mx.example.com[1.2.3.4]:25, dsn=2.0.0, status=sent (250 OK)
      Feb  2 12:34:57 mail postfix/smtp[12345]: BBBB2222: to=<bob@example.com>, relay=mx.example.com[5.6.7.8]:25, dsn=5.1.1, status=bounced (host mx.example.com said: 550 user unknown)
      Feb  2 12:34:58 mail postfix/smtp[12345]: CCCC3333: to=<carol@example.com>, relay=none, delay=300, dsn=4.4.1, status=deferred (connect to mx.example.com:25: Connection refused)
      """

      entries = Parser.parse(content)
      assert length(entries) == 1
      assert hd(entries).recipient == "bob@example.com"
    end

    test "lowercases recipient email" do
      line =
        "Feb  2 12:34:56 mail postfix/smtp[12345]: ABC123: to=<User@EXAMPLE.COM>, relay=mx.example.com[1.2.3.4]:25, dsn=5.1.1, status=bounced (550 no such user)"

      assert [entry] = Parser.parse(line)
      assert entry.recipient == "user@example.com"
    end
  end
end
