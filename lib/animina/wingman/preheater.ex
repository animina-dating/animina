defmodule Animina.Wingman.Preheater do
  @moduledoc """
  Nightly batch orchestrator for pre-computing wingman conversation hints.

  Called by Quantum cron at 00:00 Berlin time. Seeds today's spotlight
  entries for each wingman user, then enqueues AI jobs at priority 5
  (lowest) so they process whenever GPU/CPU is idle.

  Can also be called manually from IEx or dev seeds.
  """

  import Ecto.Query

  alias Animina.Accounts.User
  alias Animina.AI
  alias Animina.AI.Job
  alias Animina.Discovery.Schemas.SpotlightEntry
  alias Animina.Discovery.Spotlight
  alias Animina.FeatureFlags
  alias Animina.Repo
  alias Animina.Wingman
  alias Animina.Wingman.WingmanSuggestion

  require Logger

  @doc """
  Runs the full preheating batch.

  1. Checks wingman feature flag
  2. Cancels leftover preheated_wingman jobs from previous days
  3. Cleans up old preheated hints
  4. Lists eligible wingman users
  5. Seeds spotlight entries and enqueues AI jobs for each pair
  """
  def run do
    if FeatureFlags.wingman_enabled?() do
      do_run()
    else
      Logger.info("Preheater: wingman disabled, skipping")
      :disabled
    end
  end

  defp do_run do
    today = berlin_today()
    Logger.info("Preheater: starting batch for #{today}")

    cancelled = cancel_leftover_jobs()
    cleaned = Wingman.cleanup_old_preheated_hints()

    Logger.info(
      "Preheater: cancelled #{cancelled} leftover job(s), cleaned #{cleaned} old hint(s)"
    )

    users = list_wingman_users()
    Logger.info("Preheater: found #{length(users)} wingman user(s)")

    {enqueued, skipped} = process_users(users, today)

    Logger.info(
      "Preheater: done — enqueued #{enqueued} job(s), skipped #{skipped} existing hint(s)"
    )

    %{enqueued: enqueued, skipped: skipped, users: length(users), cancelled: cancelled}
  end

  defp process_users(users, today) do
    Enum.reduce(users, {0, 0}, fn user, {enqueued_acc, skipped_acc} ->
      {enqueued, skipped} = process_user(user, today)
      {enqueued_acc + enqueued, skipped_acc + skipped}
    end)
  end

  defp process_user(user, today) do
    # Seed today's spotlight entries (idempotent)
    spotlight_user_ids = seed_and_load_spotlight_ids(user, today)

    Enum.reduce(spotlight_user_ids, {0, 0}, fn other_user_id, {enq, skip} ->
      if hint_exists?(user.id, other_user_id, today) do
        {enq, skip + 1}
      else
        maybe_enqueue(user, other_user_id, today, enq, skip)
      end
    end)
  end

  defp maybe_enqueue(user, other_user_id, today, enq, skip) do
    case enqueue_preheated_job(user, other_user_id, today) do
      {:ok, _} -> {enq + 1, skip}
      {:error, _} -> {enq, skip}
    end
  end

  defp seed_and_load_spotlight_ids(user, today) do
    # Trigger spotlight seeding (idempotent — returns existing if already seeded)
    Spotlight.get_or_seed_daily(user)

    # Load today's spotlight entry user IDs directly
    SpotlightEntry
    |> where([e], e.user_id == ^user.id and e.shown_on == ^today)
    |> select([e], e.shown_user_id)
    |> Repo.all()
  end

  defp hint_exists?(user_id, other_user_id, today) do
    from(ws in WingmanSuggestion,
      where:
        is_nil(ws.conversation_id) and
          ws.user_id == ^user_id and
          ws.other_user_id == ^other_user_id and
          ws.shown_on == ^today
    )
    |> Repo.exists?()
  end

  defp enqueue_preheated_job(user, other_user_id, today) do
    other_user = Animina.Accounts.get_user(other_user_id)

    if is_nil(other_user) do
      {:error, :user_not_found}
    else
      context = Wingman.gather_context(user, other_user, [])
      hash = Wingman.context_hash(context)
      language = user.language || "de"
      prompt = Wingman.build_prompt(context, language)

      params = %{
        "user_id" => user.id,
        "other_user_id" => other_user_id,
        "shown_on" => Date.to_iso8601(today),
        "prompt" => prompt,
        "context_hash" => hash
      }

      AI.enqueue("wingman_suggestion", params, requester_id: user.id, priority: 50)
    end
  end

  defp list_wingman_users do
    User
    |> where([u], u.wingman_enabled == true)
    |> where([u], u.state == "normal")
    |> where([u], not is_nil(u.confirmed_at))
    |> where([u], is_nil(u.deleted_at))
    |> order_by([u], desc: u.updated_at)
    |> Repo.all()
  end

  defp cancel_leftover_jobs do
    {count, _} =
      Job
      |> where([j], j.job_type == "wingman_suggestion")
      |> where([j], j.status in ~w(pending scheduled))
      |> where([j], fragment("(params->>'conversation_id') IS NULL"))
      |> Repo.update_all(
        set: [status: "cancelled", error: "Batch reset", updated_at: DateTime.utc_now()]
      )

    count
  end

  defp berlin_today, do: Wingman.berlin_today()
end
