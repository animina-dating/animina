defmodule Animina.ReportsFixtures do
  @moduledoc """
  Test helpers for creating report-related entities.
  """

  alias Animina.AccountsFixtures
  alias Animina.Reports

  @doc """
  Creates a report between two users.
  """
  def report_fixture(attrs \\ %{}) do
    reporter = Map.get_lazy(attrs, :reporter, fn -> AccountsFixtures.user_fixture() end)
    reported_user = Map.get_lazy(attrs, :reported_user, fn -> AccountsFixtures.user_fixture() end)

    report_attrs = %{
      category: Map.get(attrs, :category, "harassment"),
      description: Map.get(attrs, :description, "Test report"),
      context_type: Map.get(attrs, :context_type, "profile"),
      context_reference_id: Map.get(attrs, :context_reference_id)
    }

    {:ok, report} = Reports.file_report(reporter, reported_user, report_attrs)
    %{report: report, reporter: reporter, reported_user: reported_user}
  end

  @doc """
  Creates and resolves a report.
  """
  def resolved_report_fixture(attrs \\ %{}) do
    %{report: report, reporter: reporter, reported_user: reported_user} = report_fixture(attrs)
    moderator = Map.get_lazy(attrs, :moderator, fn -> AccountsFixtures.moderator_fixture() end)
    resolution = Map.get(attrs, :resolution, "warning")
    notes = Map.get(attrs, :notes, "Test resolution")

    {:ok, resolved_report} = Reports.resolve_report(report, moderator, resolution, notes)

    %{
      report: resolved_report,
      reporter: reporter,
      reported_user: reported_user,
      moderator: moderator
    }
  end
end
