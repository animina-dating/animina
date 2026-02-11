defmodule Animina.Reports.Filing do
  @moduledoc """
  Handles filing new reports including evidence capture,
  invisibility creation, and notification.
  """

  alias Animina.ActivityLog
  alias Animina.Messaging
  alias Animina.Reports.Evidence
  alias Animina.Reports.IdentityHash
  alias Animina.Reports.Invisibility
  alias Animina.Reports.Report
  alias Animina.Reports.ReportNotifier
  alias Animina.Repo

  @category_priorities %{
    "underage_suspicion" => "critical",
    "threatening_behavior" => "critical",
    "harassment" => "high",
    "scam_spam" => "medium",
    "inappropriate_content" => "medium",
    "fake_profile" => "low",
    "serial_false_reporter" => "medium",
    "other" => "low"
  }

  @doc """
  Files a report against a user.

  This is a transaction that:
  1. Creates the report with derived priority
  2. Captures evidence snapshots
  3. Creates bidirectional invisibility
  4. Blocks conversation if chat context
  5. Sends generic notification email
  6. Logs to activity log
  """
  def file_report(reporter, reported_user, attrs) do
    category = Map.get(attrs, :category) || Map.get(attrs, "category")
    priority = Map.get(@category_priorities, category, "low")

    reporter_phone_hash = IdentityHash.hash_phone(reporter.mobile_phone)
    reported_phone_hash = IdentityHash.hash_phone(reported_user.mobile_phone)

    report_attrs =
      attrs
      |> Map.merge(%{
        reporter_id: reporter.id,
        reported_user_id: reported_user.id,
        reporter_phone_hash: reporter_phone_hash,
        reported_phone_hash: reported_phone_hash,
        priority: priority,
        status: "pending"
      })

    Repo.transaction(fn ->
      # 1. Insert report
      {:ok, report} =
        %Report{}
        |> Report.changeset(report_attrs)
        |> Repo.insert()

      # 2. Capture evidence
      context_type = Map.get(attrs, :context_type) || Map.get(attrs, "context_type")

      context_ref =
        Map.get(attrs, :context_reference_id) || Map.get(attrs, "context_reference_id")

      {:ok, _evidence} =
        Evidence.capture_snapshot(report, reported_user, %{
          context_type: context_type,
          context_reference_id: context_ref
        })

      # 3. Create bidirectional invisibility
      :ok = Invisibility.create_mutual_invisibility(reporter, reported_user, report)

      # 4. Block conversation if chat context
      if context_type == "chat" && context_ref do
        Messaging.block_in_conversation(context_ref, reporter.id)
      end

      # 5. Send generic notification email
      ReportNotifier.deliver_report_notice(reported_user)

      # 6. Log to activity log
      ActivityLog.log(
        "social",
        "report_filed",
        "#{reporter.display_name} reported #{reported_user.display_name}",
        actor_id: reporter.id,
        subject_id: reported_user.id,
        metadata: %{"report_id" => report.id, "category" => category}
      )

      report
    end)
  end

  @doc """
  Files a system-generated report (e.g., karen detection).
  No reporter, no evidence capture, no email notification.
  """
  def file_system_report(reported_user, attrs) do
    category = Map.get(attrs, :category) || Map.get(attrs, "category")
    priority = Map.get(@category_priorities, category, "medium")

    reported_phone_hash = IdentityHash.hash_phone(reported_user.mobile_phone)
    # System reports use the reported user's own hash as reporter hash placeholder
    reporter_phone_hash = reported_phone_hash

    report_attrs =
      attrs
      |> Map.merge(%{
        reporter_id: nil,
        reported_user_id: reported_user.id,
        reporter_phone_hash: reporter_phone_hash,
        reported_phone_hash: reported_phone_hash,
        priority: priority,
        status: "pending",
        context_type: "profile"
      })

    %Report{}
    |> Report.changeset(report_attrs)
    |> Repo.insert()
  end

  def category_priorities, do: @category_priorities
end
