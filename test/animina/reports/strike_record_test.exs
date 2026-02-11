defmodule Animina.Reports.StrikeRecordTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports

  describe "strike persistence" do
    test "strikes are keyed by phone hash and survive across reports" do
      reported_user = AccountsFixtures.user_fixture()
      moderator = AccountsFixtures.moderator_fixture()

      # First strike
      reporter1 = AccountsFixtures.user_fixture()

      {:ok, report1} =
        Reports.file_report(reporter1, reported_user, %{
          category: "harassment",
          context_type: "profile"
        })

      {:ok, _} = Reports.resolve_report(report1, moderator, "warning", "Strike 1")

      assert Reports.strike_count(reported_user) == 1

      # Second strike
      reporter2 = AccountsFixtures.user_fixture()

      {:ok, report2} =
        Reports.file_report(reporter2, reported_user, %{
          category: "scam_spam",
          context_type: "profile"
        })

      {:ok, _} = Reports.resolve_report(report2, moderator, "warning", "Strike 2")

      assert Reports.strike_count(reported_user) == 2

      # History has both
      history = Reports.strike_history(reported_user)
      assert length(history) == 2
      categories = Enum.map(history, & &1.category)
      assert "harassment" in categories
      assert "scam_spam" in categories
    end

    test "dismissed reports do not create strikes" do
      reported_user = AccountsFixtures.user_fixture()
      reporter = AccountsFixtures.user_fixture()
      moderator = AccountsFixtures.moderator_fixture()

      {:ok, report} =
        Reports.file_report(reporter, reported_user, %{category: "other", context_type: "profile"})

      {:ok, _} = Reports.resolve_report(report, moderator, "dismissed", "False report")

      assert Reports.strike_count(reported_user) == 0
    end
  end
end
