defmodule Animina.Reports.Moderation do
  @moduledoc """
  Handles report resolution, the 3-strike system, and moderation actions.

  Resolution flow (as a transaction):
  1. Updates report status to "resolved"
  2. Creates a strike record (unless dismissed)
  3. Applies user state changes (suspend/ban/warn)
  4. Creates registration bans if permanent ban
  5. Sends decision email to the reported user
  6. Checks false-reporter status of the reporter
  7. Logs the event to the activity log

  Strike system: strikes are keyed by SHA-256 phone hash and survive
  account deletion. Recommended escalation: warning → 7-day ban → permanent ban.
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.ActivityLog
  alias Animina.Repo
  alias Animina.Repo.Paginator
  alias Animina.Reports.IdentityHash
  alias Animina.Reports.KarenDetection
  alias Animina.Reports.RegistrationBan
  alias Animina.Reports.Report
  alias Animina.Reports.ReportNotifier
  alias Animina.Reports.StrikeRecord
  alias Animina.TimeMachine

  # --- Listing ---

  @doc "Lists pending reports ordered by priority (critical first)."
  def list_pending_reports(opts \\ []) do
    Report
    |> where([r], r.status in ["pending", "under_review"])
    |> priority_order()
    |> preload([:reporter, :reported_user, :evidence])
    |> Paginator.paginate(opts)
  end

  @doc "Counts pending reports."
  def count_pending_reports(_opts \\ []) do
    Report
    |> where([r], r.status in ["pending", "under_review"])
    |> Repo.aggregate(:count)
  end

  @doc "Gets a report by ID with all associations preloaded."
  def get_report!(id) do
    Report
    |> Repo.get!(id)
    |> preload_report()
  end

  @doc "Gets a report by ID, returns nil if not found."
  def get_report(id) do
    case Repo.get(Report, id) do
      nil -> nil
      report -> preload_report(report)
    end
  end

  defp preload_report(report),
    do: Repo.preload(report, [:reporter, :reported_user, :evidence, :appeal])

  # --- Resolution ---

  @doc """
  Resolves a report with the given resolution.

  Valid resolutions: `"warning"`, `"temp_ban_3"`, `"temp_ban_7"`,
  `"temp_ban_30"`, `"permanent_ban"`, `"dismissed"`.
  """
  def resolve_report(report, moderator, resolution, notes \\ "") do
    now = TimeMachine.utc_now(:second)
    report = Repo.preload(report, [:reported_user, :reporter])

    Repo.transaction(fn ->
      {:ok, report} =
        report
        |> Report.resolve_changeset(%{
          resolution: resolution,
          resolution_notes: notes,
          resolver_id: moderator.id,
          resolved_at: now
        })
        |> Repo.update()

      apply_report_resolution(report, moderator, resolution, now)

      if report.reporter_id do
        KarenDetection.check_reporter(report.reporter_id)
      end

      report
    end)
  end

  defp apply_report_resolution(report, moderator, "dismissed", _now) do
    ActivityLog.log("admin", "report_resolved", "#{moderator.display_name} dismissed report",
      actor_id: moderator.id,
      metadata: %{"report_id" => report.id, "resolution" => "dismissed"}
    )
  end

  defp apply_report_resolution(report, moderator, resolution, now) do
    reported_user = report.reported_user

    if reported_user do
      record_strike(reported_user, report, resolution, now)
      apply_resolution(reported_user, resolution, report)

      if resolution == "permanent_ban" do
        create_registration_bans(reported_user, report)
      end

      send_decision_email(reported_user, resolution, report)
      log_resolution(moderator, reported_user, report, resolution)
    end
  end

  defp record_strike(user, report, resolution, now) do
    {phone_hash, email_hash} = IdentityHash.hash_pair(user)

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
  end

  defp apply_resolution(_user, "warning", _report), do: :ok

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

    Accounts.delete_all_user_sessions(user)
  end

  defp apply_resolution(_, _, _), do: :ok

  defp create_registration_bans(user, report) do
    {phone_hash, email_hash} = IdentityHash.hash_pair(user)

    for {type, hash} <- [{"phone", phone_hash}, {"email", email_hash}] do
      %RegistrationBan{}
      |> RegistrationBan.changeset(%{
        ban_type: type,
        hash_value: hash,
        report_id: report.id,
        notes: "Auto-created from permanent ban"
      })
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:ban_type, :hash_value])
    end
  end

  defp send_decision_email(user, "warning", report) do
    ReportNotifier.deliver_report_warning(user, report.category)
  end

  defp send_decision_email(user, "temp_ban_" <> days_str, report) do
    days = String.to_integer(days_str)

    suspended_until =
      user.suspended_until ||
        TimeMachine.utc_now() |> DateTime.add(days, :day) |> DateTime.truncate(:second)

    ReportNotifier.deliver_report_suspension(user, days, suspended_until, report.category)
  end

  defp send_decision_email(user, "permanent_ban", report) do
    ReportNotifier.deliver_report_permanent_ban(user, report.category)
  end

  defp send_decision_email(_, _, _), do: :ok

  defp log_resolution(moderator, reported_user, report, resolution) do
    ActivityLog.log(
      "admin",
      resolution_event(resolution),
      "#{moderator.display_name} #{resolution_summary(resolution)} #{reported_user.display_name}",
      actor_id: moderator.id,
      subject_id: reported_user.id,
      metadata: %{"report_id" => report.id, "resolution" => resolution}
    )
  end

  defp resolution_event("warning"), do: "user_warned"
  defp resolution_event("permanent_ban"), do: "user_banned"
  defp resolution_event("temp_ban_" <> _), do: "user_suspended"
  defp resolution_event(_), do: "report_resolved"

  defp resolution_summary("warning"), do: "warned"
  defp resolution_summary("permanent_ban"), do: "permanently banned"
  defp resolution_summary("temp_ban_" <> d), do: "suspended (#{d} days)"
  defp resolution_summary(_), do: "resolved report for"

  # --- Strike System ---

  @doc "Returns the full strike history for a user (by phone hash). Works across account deletions."
  def strike_history(user) do
    user
    |> strikes_query()
    |> order_by([s], desc: s.resolved_at)
    |> Repo.all()
  end

  @doc "Returns the strike count for a user (by phone hash)."
  def strike_count(user) do
    user
    |> strikes_query()
    |> Repo.aggregate(:count)
  end

  defp strikes_query(user) do
    phone_hash = IdentityHash.hash_phone(user.mobile_phone)
    where(StrikeRecord, [s], s.phone_hash == ^phone_hash)
  end

  @doc """
  Returns the recommended resolution based on strike count.

  - 0 prior strikes → `"warning"`
  - 1 prior strike → `"temp_ban_7"`
  - 2+ prior strikes → `"permanent_ban"`
  """
  def recommended_action(user) do
    case strike_count(user) do
      0 -> "warning"
      1 -> "temp_ban_7"
      _ -> "permanent_ban"
    end
  end

  # --- Registration Ban Check ---

  @doc "Checks if a phone or email is banned from registration (by hash)."
  def registration_banned?(phone, email) do
    phone_hash = IdentityHash.hash_phone(phone)
    email_hash = IdentityHash.hash_email(email)

    RegistrationBan
    |> where([b], b.hash_value in ^[phone_hash, email_hash])
    |> Repo.exists?()
  end

  # --- Reporter Statistics ---

  @doc "Returns report filing statistics for a reporter (total, dismissed, upheld, upheld %)."
  def reporter_stats(reporter_id) do
    total =
      Report
      |> where([r], r.reporter_id == ^reporter_id and r.status == "resolved")
      |> Repo.aggregate(:count)

    dismissed =
      Report
      |> where([r], r.reporter_id == ^reporter_id and r.resolution == "dismissed")
      |> Repo.aggregate(:count)

    upheld = total - dismissed
    upheld_pct = if total > 0, do: round(upheld / total * 100), else: 0

    %{total: total, dismissed: dismissed, upheld: upheld, upheld_pct: upheld_pct}
  end

  # --- Suspension Expiry ---

  @doc """
  Auto-unsuspends a user if their suspension has expired.
  Returns the user (possibly updated). Called on every auth check.
  """
  def maybe_unsuspend(user) do
    suspension_expired? =
      user.state == "suspended" &&
        user.suspended_until &&
        DateTime.compare(TimeMachine.utc_now(), user.suspended_until) != :lt

    if suspension_expired? do
      {:ok, updated} =
        user
        |> User.moderation_changeset(%{state: "normal", suspended_until: nil})
        |> Repo.update()

      ActivityLog.log(
        "admin",
        "user_unsuspended",
        "#{user.display_name} auto-unsuspended (suspension expired)",
        subject_id: user.id
      )

      updated
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
