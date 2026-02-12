defmodule Animina.Reports do
  @moduledoc """
  Context for the user reporting and moderation system.

  Delegates to specialized sub-modules:

  - `Filing` — filing new reports (creates report, captures evidence, establishes invisibility)
  - `Moderation` — report resolution, 3-strike system, suspension/ban management
  - `Appeals` — appeal workflow (one appeal per report, different reviewer required)
  - `Invisibility` — bidirectional invisibility between users (survives account deletion)
  - `KarenDetection` — auto-flags serial false reporters (70%+ dismissed after 5+ reports)
  - `IdentityHash` — SHA-256 hashing of phone/email for persistent identity tracking
  - `Category` — single source of truth for category keys, labels, and priorities
  """

  # --- Filing ---

  defdelegate file_report(reporter, reported_user, attrs), to: Animina.Reports.Filing
  defdelegate file_system_report(reported_user, attrs), to: Animina.Reports.Filing

  # --- Moderation ---

  defdelegate list_pending_reports(opts \\ []), to: Animina.Reports.Moderation
  defdelegate count_pending_reports(opts \\ []), to: Animina.Reports.Moderation
  defdelegate get_report!(id), to: Animina.Reports.Moderation
  defdelegate get_report(id), to: Animina.Reports.Moderation

  defdelegate resolve_report(report, moderator, resolution, notes \\ ""),
    to: Animina.Reports.Moderation

  defdelegate strike_history(user), to: Animina.Reports.Moderation
  defdelegate strike_count(user), to: Animina.Reports.Moderation
  defdelegate recommended_action(user), to: Animina.Reports.Moderation
  defdelegate reporter_stats(reporter_id), to: Animina.Reports.Moderation
  defdelegate registration_banned?(phone, email), to: Animina.Reports.Moderation
  defdelegate maybe_unsuspend(user), to: Animina.Reports.Moderation

  # --- Invisibility ---

  defdelegate hidden?(user_id, other_id), to: Animina.Reports.Invisibility
  defdelegate hidden_user_ids(user_id), to: Animina.Reports.Invisibility
  defdelegate restore_invisibilities_for_new_user(user), to: Animina.Reports.Invisibility

  # --- Appeals ---

  defdelegate create_appeal(report, user, appeal_text), to: Animina.Reports.Appeals
  defdelegate list_pending_appeals(opts \\ []), to: Animina.Reports.Appeals
  defdelegate count_pending_appeals(opts \\ []), to: Animina.Reports.Appeals
  defdelegate get_appeal!(id), to: Animina.Reports.Appeals
  defdelegate resolve_appeal(appeal, reviewer, decision, notes \\ ""), to: Animina.Reports.Appeals

  # --- False Reporter Detection ---

  defdelegate check_reporter(reporter_id), to: Animina.Reports.KarenDetection
end
