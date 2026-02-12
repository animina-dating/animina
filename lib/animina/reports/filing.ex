defmodule Animina.Reports.Filing do
  @moduledoc """
  Handles filing new reports.

  Filing a report triggers a transaction that creates the report with
  auto-derived priority, captures evidence snapshots, establishes mutual
  invisibility, blocks the conversation (if chat context), sends a
  notification email, and logs the event.
  """

  alias Animina.ActivityLog
  alias Animina.Messaging
  alias Animina.Repo
  alias Animina.Reports.Category
  alias Animina.Reports.Evidence
  alias Animina.Reports.IdentityHash
  alias Animina.Reports.Invisibility
  alias Animina.Reports.Report
  alias Animina.Reports.ReportNotifier

  @doc """
  Files a report from one user against another.

  Returns `{:ok, report}` inside a transaction that also captures evidence,
  creates bidirectional invisibility, and sends a notification email.
  """
  def file_report(reporter, reported_user, attrs) do
    category = attrs[:category] || attrs["category"]
    context_type = attrs[:context_type] || attrs["context_type"]
    context_ref = attrs[:context_reference_id] || attrs["context_reference_id"]

    report_attrs =
      Map.merge(attrs, %{
        reporter_id: reporter.id,
        reported_user_id: reported_user.id,
        reporter_phone_hash: IdentityHash.hash_phone(reporter.mobile_phone),
        reported_phone_hash: IdentityHash.hash_phone(reported_user.mobile_phone),
        priority: Category.priority(category),
        status: "pending"
      })

    Repo.transaction(fn ->
      {:ok, report} =
        %Report{}
        |> Report.changeset(report_attrs)
        |> Repo.insert()

      {:ok, _evidence} =
        Evidence.capture_snapshot(report, reported_user, %{
          context_type: context_type,
          context_reference_id: context_ref
        })

      :ok = Invisibility.create_mutual_invisibility(reporter, reported_user, report)

      if context_type == "chat" && context_ref do
        Messaging.block_in_conversation(context_ref, reporter.id)
      end

      ReportNotifier.deliver_report_notice(reported_user)

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
  Files a system-generated report (e.g. from false reporter detection).
  No reporter, no evidence capture, no notification email.
  """
  def file_system_report(reported_user, attrs) do
    category = attrs[:category] || attrs["category"]
    phone_hash = IdentityHash.hash_phone(reported_user.mobile_phone)

    report_attrs =
      Map.merge(attrs, %{
        reporter_id: nil,
        reported_user_id: reported_user.id,
        reporter_phone_hash: phone_hash,
        reported_phone_hash: phone_hash,
        priority: Category.priority(category),
        status: "pending",
        context_type: "profile"
      })

    %Report{}
    |> Report.changeset(report_attrs)
    |> Repo.insert()
  end
end
