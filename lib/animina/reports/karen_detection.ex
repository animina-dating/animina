defmodule Animina.Reports.KarenDetection do
  @moduledoc """
  Detects serial false reporters.

  Called after each report resolution. If a reporter has filed 5+ reports
  and 70%+ were dismissed, auto-creates a system report with category
  `"serial_false_reporter"` against them. Only one such report per reporter.
  """

  import Ecto.Query

  alias Animina.ActivityLog
  alias Animina.Repo
  alias Animina.Reports.Filing
  alias Animina.Reports.Report

  @min_reports 5
  @dismiss_threshold 0.70

  @doc """
  Checks if a reporter has exceeded the false report threshold.
  Called after each report resolution.
  """
  def check_reporter(reporter_id) do
    stats = reporter_resolution_stats(reporter_id)

    cond do
      stats.total < @min_reports || stats.dismiss_ratio < @dismiss_threshold ->
        :ok

      karen_report_exists?(reporter_id) ->
        :already_flagged

      true ->
        reporter = Animina.Accounts.get_user!(reporter_id)

        {:ok, report} =
          Filing.file_system_report(reporter, %{
            category: "serial_false_reporter",
            description:
              "Auto-flagged: #{stats.dismissed}/#{stats.total} reports dismissed (#{round(stats.dismiss_ratio * 100)}%)"
          })

        ActivityLog.log(
          "admin",
          "karen_auto_reported",
          "#{reporter.display_name} auto-flagged as serial false reporter (#{stats.dismissed}/#{stats.total} dismissed)",
          subject_id: reporter_id,
          metadata: %{
            "report_id" => report.id,
            "total_reports" => stats.total,
            "dismissed_count" => stats.dismissed,
            "dismiss_ratio" => stats.dismiss_ratio
          }
        )

        {:ok, report}
    end
  end

  defp reporter_resolution_stats(reporter_id) do
    total =
      Report
      |> where([r], r.reporter_id == ^reporter_id)
      |> where([r], r.status == "resolved")
      |> Repo.aggregate(:count)

    dismissed =
      Report
      |> where([r], r.reporter_id == ^reporter_id)
      |> where([r], r.resolution == "dismissed")
      |> Repo.aggregate(:count)

    dismiss_ratio = if total > 0, do: dismissed / total, else: 0.0

    %{total: total, dismissed: dismissed, dismiss_ratio: dismiss_ratio}
  end

  defp karen_report_exists?(reporter_id) do
    Report
    |> where([r], r.reported_user_id == ^reporter_id)
    |> where([r], r.category == "serial_false_reporter")
    |> Repo.exists?()
  end
end
