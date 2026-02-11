defmodule Animina.Reports.FilingTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports
  alias Animina.Reports.IdentityHash

  describe "file_report/3" do
    setup do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Alice"})
      reported_user = AccountsFixtures.user_fixture(%{display_name: "Bob"})
      %{reporter: reporter, reported_user: reported_user}
    end

    test "creates a report with correct attributes", %{
      reporter: reporter,
      reported_user: reported_user
    } do
      attrs = %{
        category: "harassment",
        description: "Harassing messages",
        context_type: "profile"
      }

      assert {:ok, report} = Reports.file_report(reporter, reported_user, attrs)
      assert report.reporter_id == reporter.id
      assert report.reported_user_id == reported_user.id
      assert report.category == "harassment"
      assert report.status == "pending"
      assert report.priority == "high"
      assert report.reporter_phone_hash == IdentityHash.hash_phone(reporter.mobile_phone)
      assert report.reported_phone_hash == IdentityHash.hash_phone(reported_user.mobile_phone)
    end

    test "captures evidence snapshot", %{reporter: reporter, reported_user: reported_user} do
      attrs = %{category: "fake_profile", context_type: "profile"}
      {:ok, report} = Reports.file_report(reporter, reported_user, attrs)

      report = Reports.get_report!(report.id)
      assert report.evidence != nil
      assert report.evidence.profile_snapshot != nil
      assert report.evidence.profile_snapshot["display_name"] == "Bob"
    end

    test "creates mutual invisibility", %{reporter: reporter, reported_user: reported_user} do
      attrs = %{category: "harassment", context_type: "profile"}
      {:ok, _report} = Reports.file_report(reporter, reported_user, attrs)

      assert Reports.hidden?(reporter.id, reported_user.id)
      assert Reports.hidden?(reported_user.id, reporter.id)
    end

    test "derives priority from category", %{reporter: reporter, reported_user: reported_user} do
      attrs = %{category: "underage_suspicion", context_type: "profile"}
      {:ok, report} = Reports.file_report(reporter, reported_user, attrs)
      assert report.priority == "critical"

      reporter2 = AccountsFixtures.user_fixture()
      reported2 = AccountsFixtures.user_fixture()
      attrs2 = %{category: "fake_profile", context_type: "profile"}
      {:ok, report2} = Reports.file_report(reporter2, reported2, attrs2)
      assert report2.priority == "low"
    end
  end
end
