defmodule Animina.Reports do
  @moduledoc """
  Context for the user reporting and moderation system.

  This module acts as a facade, delegating to specialized sub-modules:
  - `Animina.Reports.Filing` - Filing new reports
  - `Animina.Reports.Evidence` - Evidence snapshot capture
  - `Animina.Reports.Invisibility` - Mutual invisibility management
  - `Animina.Reports.Moderation` - Report resolution, strikes, bans
  - `Animina.Reports.Appeals` - Appeal workflow
  - `Animina.Reports.KarenDetection` - Serial false reporter detection
  - `Animina.Reports.IdentityHash` - SHA-256 identity hashing
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

  # --- Karen Detection ---

  defdelegate check_reporter(reporter_id), to: Animina.Reports.KarenDetection

  # --- Identity Hashing ---

  defdelegate hash_phone(phone), to: Animina.Reports.IdentityHash
  defdelegate hash_email(email), to: Animina.Reports.IdentityHash
  defdelegate hash_pair(user), to: Animina.Reports.IdentityHash
end
