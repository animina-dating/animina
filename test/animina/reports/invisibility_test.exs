defmodule Animina.Reports.InvisibilityTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports

  describe "mutual invisibility" do
    setup do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Alice"})
      reported_user = AccountsFixtures.user_fixture(%{display_name: "Bob"})

      attrs = %{category: "harassment", context_type: "profile"}
      {:ok, _report} = Reports.file_report(reporter, reported_user, attrs)

      %{reporter: reporter, reported_user: reported_user}
    end

    test "hidden?/2 returns true for both directions", %{
      reporter: reporter,
      reported_user: reported_user
    } do
      assert Reports.hidden?(reporter.id, reported_user.id)
      assert Reports.hidden?(reported_user.id, reporter.id)
    end

    test "hidden_user_ids/1 includes the other user", %{
      reporter: reporter,
      reported_user: reported_user
    } do
      hidden_from_reporter = Reports.hidden_user_ids(reporter.id)
      assert reported_user.id in hidden_from_reporter

      hidden_from_reported = Reports.hidden_user_ids(reported_user.id)
      assert reporter.id in hidden_from_reported
    end

    test "unrelated users are not hidden" do
      user_c = AccountsFixtures.user_fixture()
      user_d = AccountsFixtures.user_fixture()

      refute Reports.hidden?(user_c.id, user_d.id)
    end
  end

  describe "discovery integration" do
    test "hidden users are excluded from hidden_user_ids" do
      reporter = AccountsFixtures.user_fixture()
      reported = AccountsFixtures.user_fixture()

      # Before report: no hidden users
      assert Reports.hidden_user_ids(reporter.id) == []

      # File report
      attrs = %{category: "scam_spam", context_type: "profile"}
      {:ok, _report} = Reports.file_report(reporter, reported, attrs)

      # After report: reported user is hidden
      hidden = Reports.hidden_user_ids(reporter.id)
      assert reported.id in hidden
    end
  end
end
