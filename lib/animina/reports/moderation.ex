defmodule Animina.Reports.Moderation do
  @moduledoc """
  Handles report resolution, strike system, and moderation actions.
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.ActivityLog
  alias Animina.Reports.IdentityHash
  alias Animina.Reports.KarenDetection
  alias Animina.Reports.RegistrationBan
  alias Animina.Reports.Report
  alias Animina.Reports.ReportNotifier
  alias Animina.Reports.StrikeRecord
  alias Animina.Repo
  alias Animina.Repo.Paginator
  alias Animina.TimeMachine

  # --- Listing ---

  @doc """
  Lists pending reports ordered by priority (critical first).
  """
  def list_pending_reports(opts \\ []) do
    Report
    |> where([r], r.status in ["pending", "under_review"])
    |> priority_order()
    |> preload([:reporter, :reported_user, :evidence])
    |> Paginator.paginate(opts)
  end

  @doc """
  Counts pending reports.
  """
  def count_pending_reports(_opts \\ []) do
    Report
    |> where([r], r.status in ["pending", "under_review"])
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets a report by ID with preloads.
  """
  def get_report!(id) do
    Report
    |> Repo.get!(id)
    |> Repo.preload([:reporter, :reported_user, :evidence, :appeal])
  end

  @doc """
  Gets a report by ID, returns nil if not found.
  """
  def get_report(id) do
    Report
    |> Repo.get(id)
    |> maybe_preload()
  end

  defp maybe_preload(nil), do: nil

  defp maybe_preload(report),
    do: Repo.preload(report, [:reporter, :reported_user, :evidence, :appeal])

  # --- Resolution ---

  @doc """
  Resolves a report with the given resolution.

  This is a transaction that:
  1. Updates report status/resolution
  2. Creates strike record (unless dismissed)
  3. Applies user state changes (suspend/ban/warn)
  4. Creates registration bans if permanent ban
  5. Sends decision email
  6. Checks karen status of reporter
  7. Logs to activity log
  """
  def resolve_report(report, moderator, resolution, notes \\ "") do
    now = TimeMachine.utc_now(:second)
    report = Repo.preload(report, [:reported_user, :reporter])

    Repo.transaction(fn ->
      # 1. Update report
      {:ok, report} =
        report
        |> Report.resolve_changeset(%{
          resolution: resolution,
          resolution_notes: notes,
          resolver_id: moderator.id,
          resolved_at: now
        })
        |> Repo.update()

      reported_user = report.reported_user

      if resolution != "dismissed" && reported_user do
        # 2. Create strike record
        {phone_hash, email_hash} = IdentityHash.hash_pair(reported_user)

        {:ok, _strike} =
          %StrikeRecord{}
          |> StrikeRecord.changeset(%{
            phone_hash: phone_hash,
            email_hash: email_hash,
            report_id: report.id,
            resolution: resolution,
            category: report.category,
            resolved_at: now
          })
          |> Repo.insert()

        # 3. Apply user state changes
        apply_resolution(reported_user, resolution, report)

        # 4. Registration bans for permanent ban
        if resolution == "permanent_ban" do
          create_registration_bans(reported_user, report)
        end

        # 5. Send decision email
        send_decision_email(reported_user, resolution, report)

        # Log appropriate event
        event = resolution_event(resolution)

        ActivityLog.log(
          "admin",
          event,
          "#{moderator.display_name} #{resolution_summary(resolution)} #{reported_user.display_name}",
          actor_id: moderator.id,
          subject_id: reported_user.id,
          metadata: %{"report_id" => report.id, "resolution" => resolution}
        )
      else
        ActivityLog.log("admin", "report_resolved", "#{moderator.display_name} dismissed report",
          actor_id: moderator.id,
          metadata: %{"report_id" => report.id, "resolution" => "dismissed"}
        )
      end

      # 6. Check karen status of reporter
      if report.reporter_id do
        KarenDetection.check_reporter(report.reporter_id)
      end

      report
    end)
  end

  defp apply_resolution(_user, "warning", _report) do
    # Warning: no state change, just the email
    :ok
  end

  defp apply_resolution(user, "temp_ban_" <> days_str, _report) do
    days = String.to_integer(days_str)

    suspended_until =
      TimeMachine.utc_now() |> DateTime.add(days, :day) |> DateTime.truncate(:second)

    user
    |> User.moderation_changeset(%{state: "suspended", suspended_until: suspended_until})
    |> Repo.update!()
  end

  defp apply_resolution(user, "permanent_ban", report) do
    user
    |> User.moderation_changeset(%{
      state: "banned",
      ban_reason: "Permanent ban: #{report.category}"
    })
    |> Repo.update!()

    # Delete all sessions to force logout
    Accounts.delete_all_user_sessions(user)
  end

  defp apply_resolution(_, _, _), do: :ok

  defp create_registration_bans(user, report) do
    {phone_hash, email_hash} = IdentityHash.hash_pair(user)

    %RegistrationBan{}
    |> RegistrationBan.changeset(%{
      ban_type: "phone",
      hash_value: phone_hash,
      report_id: report.id,
      notes: "Auto-created from permanent ban"
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:ban_type, :hash_value])

    %RegistrationBan{}
    |> RegistrationBan.changeset(%{
      ban_type: "email",
      hash_value: email_hash,
      report_id: report.id,
      notes: "Auto-created from permanent ban"
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:ban_type, :hash_value])
  end

  defp send_decision_email(user, "warning", _report) do
    ReportNotifier.deliver_report_warning(user)
  end

  defp send_decision_email(user, "temp_ban_" <> _days, _report) do
    ReportNotifier.deliver_report_suspension(user)
  end

  defp send_decision_email(user, "permanent_ban", _report) do
    ReportNotifier.deliver_report_permanent_ban(user)
  end

  defp send_decision_email(_, _, _), do: :ok

  defp resolution_event("warning"), do: "user_warned"
  defp resolution_event("permanent_ban"), do: "user_banned"
  defp resolution_event("temp_ban_" <> _), do: "user_suspended"
  defp resolution_event(_), do: "report_resolved"

  defp resolution_summary("warning"), do: "warned"
  defp resolution_summary("permanent_ban"), do: "permanently banned"
  defp resolution_summary("temp_ban_" <> d), do: "suspended (#{d} days)"
  defp resolution_summary(_), do: "resolved report for"

  # --- Strike System ---

  @doc """
  Returns the strike history for a user (by phone hash).
  Works across account deletions.
  """
  def strike_history(user) do
    phone_hash = IdentityHash.hash_phone(user.mobile_phone)

    StrikeRecord
    |> where([s], s.phone_hash == ^phone_hash)
    |> order_by([s], desc: s.resolved_at)
    |> Repo.all()
  end

  @doc """
  Returns the strike count for a user (by phone hash).
  """
  def strike_count(user) do
    phone_hash = IdentityHash.hash_phone(user.mobile_phone)

    StrikeRecord
    |> where([s], s.phone_hash == ^phone_hash)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns the recommended action based on strike count.

  - 0 prior strikes → warning
  - 1 prior strike → temp_ban_7
  - 2+ prior strikes → permanent_ban
  """
  def recommended_action(user) do
    case strike_count(user) do
      0 -> "warning"
      1 -> "temp_ban_7"
      _ -> "permanent_ban"
    end
  end

  # --- Registration Ban Check ---

  @doc """
  Checks if a phone or email hash is banned from registration.
  """
  def registration_banned?(phone, email) do
    phone_hash = IdentityHash.hash_phone(phone)
    email_hash = IdentityHash.hash_email(email)

    RegistrationBan
    |> where([b], b.hash_value in ^[phone_hash, email_hash])
    |> Repo.exists?()
  end

  # --- Reporter Statistics ---

  @doc """
  Returns report filing statistics for a reporter.
  """
  def reporter_stats(reporter_id) do
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

    upheld = total - dismissed
    upheld_pct = if total > 0, do: round(upheld / total * 100), else: 0

    %{total: total, dismissed: dismissed, upheld: upheld, upheld_pct: upheld_pct}
  end

  # --- Suspension Expiry ---

  @doc """
  Checks if a suspended user's suspension has expired and auto-unsuspends.
  Returns the user (possibly updated).
  """
  def maybe_unsuspend(user) do
    if user.state == "suspended" && user.suspended_until do
      if DateTime.compare(TimeMachine.utc_now(), user.suspended_until) != :lt do
        {:ok, updated} =
          user
          |> User.moderation_changeset(%{state: "normal", suspended_until: nil})
          |> Repo.update()

        ActivityLog.log(
          "admin",
          "user_unsuspended",
          "#{user.display_name} auto-unsuspended (suspension expired)", subject_id: user.id)

        updated
      else
        user
      end
    else
      user
    end
  end

  # --- Helpers ---

  defp priority_order(query) do
    from(r in query,
      order_by: [
        asc:
          fragment(
            "CASE ? WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 ELSE 4 END",
            r.priority
          ),
        asc: r.inserted_at
      ]
    )
  end
end
