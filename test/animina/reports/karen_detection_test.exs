defmodule Animina.Reports.KarenDetectionTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports
  alias Animina.Reports.Report
  alias Animina.Repo

  import Ecto.Query

  describe "check_reporter/1" do
    test "does not flag reporter with few reports" do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Karen"})
      moderator = AccountsFixtures.moderator_fixture()

      # File and dismiss 3 reports (below threshold of 5)
      Enum.each(1..3, fn _ ->
        reported = AccountsFixtures.user_fixture()

        {:ok, report} =
          Reports.file_report(reporter, reported, %{category: "other", context_type: "profile"})

        {:ok, _} = Reports.resolve_report(report, moderator, "dismissed", "False report")
      end)

      # No auto-report should exist
      refute karen_report_exists?(reporter.id)
    end

    test "auto-flags reporter with high dismiss ratio on 5th dismissed resolve" do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Karen"})
      moderator = AccountsFixtures.moderator_fixture()

      # File and dismiss 5 reports — the 5th resolve triggers karen detection
      Enum.each(1..5, fn _ ->
        reported = AccountsFixtures.user_fixture()

        {:ok, report} =
          Reports.file_report(reporter, reported, %{category: "other", context_type: "profile"})

        {:ok, _} = Reports.resolve_report(report, moderator, "dismissed", "False report")
      end)

      # Auto-report should have been created during the 5th resolution
      assert karen_report_exists?(reporter.id)

      auto_report = get_karen_report(reporter.id)
      assert auto_report.category == "serial_false_reporter"
      assert auto_report.reported_user_id == reporter.id
    end

    test "does not double-flag same reporter" do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Karen"})
      moderator = AccountsFixtures.moderator_fixture()

      # 5 dismissed reports → triggers auto-flag inside resolve_report
      Enum.each(1..5, fn _ ->
        reported = AccountsFixtures.user_fixture()

        {:ok, report} =
          Reports.file_report(reporter, reported, %{category: "other", context_type: "profile"})

        {:ok, _} = Reports.resolve_report(report, moderator, "dismissed", "False report")
      end)

      assert karen_report_exists?(reporter.id)

      # Calling check_reporter again returns :already_flagged
      assert :already_flagged = Reports.check_reporter(reporter.id)

      # Still only one karen report
      count =
        Report
        |> where(
          [r],
          r.reported_user_id == ^reporter.id and r.category == "serial_false_reporter"
        )
        |> Repo.aggregate(:count)

      assert count == 1
    end
  end

  defp karen_report_exists?(reporter_id) do
    Report
    |> where([r], r.reported_user_id == ^reporter_id and r.category == "serial_false_reporter")
    |> Repo.exists?()
  end

  defp get_karen_report(reporter_id) do
    Report
    |> where([r], r.reported_user_id == ^reporter_id and r.category == "serial_false_reporter")
    |> Repo.one!()
  end
end
