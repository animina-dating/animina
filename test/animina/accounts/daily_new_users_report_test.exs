defmodule Animina.Accounts.DailyNewUsersReportTest do
  use Animina.DataCase, async: true

  import Animina.AccountsFixtures
  import Swoosh.TestAssertions

  alias Animina.Accounts.DailyNewUsersReport

  describe "run/0" do
    test "sends email when there are confirmed users in the last 24h" do
      _user = user_fixture()

      assert {:ok, _email} = DailyNewUsersReport.run()
      assert_email_sent(subject: ~r/1/)
    end

    test "does not send email when there are no confirmed users" do
      assert :ok = DailyNewUsersReport.run()
      refute_email_sent()
    end

    test "includes correct count in email" do
      _user1 = user_fixture()
      _user2 = user_fixture()

      assert {:ok, email} = DailyNewUsersReport.run()
      assert email.subject =~ "2"
      assert email.text_body =~ "2"
    end
  end
end
