defmodule Animina.Reports.Appeals do
  @moduledoc """
  Handles report appeals.

  Constraints:
  - One appeal per report (enforced by unique constraint)
  - Only the reported user can file an appeal
  - Must be reviewed by a different moderator than the original resolver
  - Approved appeals restore the user's account and remove registration bans
  """

  import Ecto.Query

  alias Animina.Accounts.User
  alias Animina.ActivityLog
  alias Animina.Repo
  alias Animina.Repo.Paginator
  alias Animina.Reports.RegistrationBan
  alias Animina.Reports.ReportAppeal
  alias Animina.Reports.ReportNotifier
  alias Animina.TimeMachine

  @doc """
  Creates an appeal for a report.

  Validates:
  - One appeal per report
  - User must be the reported user
  """
  def create_appeal(report, user, appeal_text) do
    report = Repo.preload(report, [:appeal])

    cond do
      report.appeal != nil ->
        {:error, :appeal_already_exists}

      report.reported_user_id != user.id ->
        {:error, :not_reported_user}

      report.status != "resolved" ->
        {:error, :report_not_resolved}

      true ->
        with {:ok, appeal} <-
               %ReportAppeal{}
               |> ReportAppeal.changeset(%{
                 report_id: report.id,
                 appellant_id: user.id,
                 appeal_text: appeal_text
               })
               |> Repo.insert() do
          ActivityLog.log(
            "social",
            "report_appeal_filed",
            "#{user.display_name} appealed report decision",
            actor_id: user.id,
            metadata: %{"report_id" => report.id, "appeal_id" => appeal.id}
          )

          {:ok, appeal}
        end
    end
  end

  @doc """
  Lists pending appeals.
  """
  def list_pending_appeals(opts \\ []) do
    ReportAppeal
    |> where([a], a.status == "pending")
    |> order_by([a], asc: a.inserted_at)
    |> preload([:appellant, report: [:reporter, :reported_user, :evidence]])
    |> Paginator.paginate(opts)
  end

  @doc """
  Counts pending appeals.
  """
  def count_pending_appeals(_opts \\ []) do
    ReportAppeal
    |> where([a], a.status == "pending")
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets an appeal by ID with preloads.
  """
  def get_appeal!(id) do
    ReportAppeal
    |> Repo.get!(id)
    |> Repo.preload([:appellant, report: [:reporter, :reported_user, :evidence]])
  end

  @doc """
  Resolves an appeal.

  Enforces that the reviewer is different from the original report resolver.
  """
  def resolve_appeal(appeal, reviewer, decision, notes \\ "") do
    appeal = Repo.preload(appeal, report: [:reported_user])
    report = appeal.report

    cond do
      report.resolver_id == reviewer.id ->
        {:error, :same_moderator}

      appeal.status != "pending" ->
        {:error, :already_resolved}

      true ->
        now = TimeMachine.utc_now(:second)

        Repo.transaction(fn ->
          {:ok, appeal} =
            appeal
            |> ReportAppeal.resolve_changeset(%{
              status: decision,
              reviewer_id: reviewer.id,
              resolution_notes: notes,
              resolved_at: now
            })
            |> Repo.update()

          apply_appeal_decision(decision, report, appeal, reviewer)
          appeal
        end)
    end
  end

  defp apply_appeal_decision("approved", report, appeal, reviewer) do
    reported_user = report.reported_user

    if reported_user do
      {:ok, _} =
        reported_user
        |> User.moderation_changeset(%{state: "normal", suspended_until: nil, ban_reason: nil})
        |> Repo.update()

      remove_registration_bans_for_report(report.id)
      ReportNotifier.deliver_report_appeal_approved(reported_user)

      ActivityLog.log(
        "admin",
        "user_unsuspended",
        "#{reviewer.display_name} approved appeal for #{reported_user.display_name}",
        actor_id: reviewer.id,
        subject_id: reported_user.id,
        metadata: %{"report_id" => report.id, "appeal_id" => appeal.id}
      )
    end
  end

  defp apply_appeal_decision(_decision, report, appeal, reviewer) do
    reported_user = report.reported_user

    if reported_user do
      ReportNotifier.deliver_report_appeal_rejected(reported_user)
    end

    ActivityLog.log(
      "admin",
      "report_appeal_resolved",
      "#{reviewer.display_name} rejected appeal",
      actor_id: reviewer.id,
      subject_id: if(reported_user, do: reported_user.id),
      metadata: %{"report_id" => report.id, "appeal_id" => appeal.id, "decision" => "rejected"}
    )
  end

  defp remove_registration_bans_for_report(report_id) do
    from(b in RegistrationBan, where: b.report_id == ^report_id)
    |> Repo.delete_all()
  end
end
