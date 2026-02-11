defmodule Animina.Reports.KarenDetection do
  @moduledoc """
  Detects serial false reporters ("Karens").

  If a reporter has 5+ resolved reports and 70%+ are dismissed,
  auto-creates a system report against them.
  """

  import Ecto.Query

  alias Animina.ActivityLog
  alias Animina.Reports.Filing
  alias Animina.Reports.Report
  alias Animina.Repo

  @min_reports 5
  @dismiss_threshold 0.70

  @doc """
  Checks if a reporter has exceeded the false report threshold.
  Called after each report resolution.
  """
  def check_reporter(reporter_id) do
    stats = reporter_resolution_stats(reporter_id)

    if stats.total >= @min_reports && stats.dismiss_ratio >= @dismiss_threshold do
      # Only create one karen report per reporter
      unless karen_report_exists?(reporter_id) do
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
      else
        :already_flagged
      end
    else
      :ok
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
