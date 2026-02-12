defmodule Animina.Discovery.Spotlight do
  @moduledoc """
  Daily Spotlight system for partner discovery.

  Seeds 6 candidates from the candidate pool (round-robin) plus 2 wildcards
  from an expanded pool once per day at first visit. The same set is shown
  all day, resetting at Berlin midnight.
  """

  import Ecto.Query

  alias Animina.Accounts.Scope
  alias Animina.Accounts.User
  alias Animina.Discovery
  alias Animina.Discovery.Schemas.SpotlightEntry
  alias Animina.Discovery.SpotlightPool
  alias Animina.Discovery.WildcardPool
  alias Animina.Messaging
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Utils.Timezone

  @pool_picks 6
  @wildcard_picks 2

  @doc """
  Returns today's spotlight candidates for the viewer.

  If entries exist for today (Berlin time), loads and returns them.
  Otherwise seeds a new set via the round-robin algorithm.

  Returns a list of `%User{}` structs. Each has an `is_spotlight_wildcard`
  field in its metadata map available via the returned entries.
  Returns `{users, wildcard_ids}` where wildcard_ids is a MapSet.
  """
  def get_or_seed_daily(viewer) do
    today = berlin_today()

    case load_today_entries(viewer.id, today) do
      [] ->
        seed_daily(viewer, today)
        load_spotlight_users(viewer.id, today)

      entries ->
        entries_to_users(entries)
    end
  end

  @doc """
  Checks if a viewer has moodboard access to a profile user.

  Access is granted if any of:
  1. Viewer is the profile owner
  2. Viewer is admin or moderator
  3. They have an active (non-blocked) conversation
  4. They are in each other's today spotlight (bidirectional)
  """
  def has_moodboard_access?(viewer, profile_user, scope) do
    cond do
      # Owner
      viewer && profile_user && viewer.id == profile_user.id ->
        true

      # Admin or moderator
      Scope.admin?(scope) || Scope.moderator?(scope) ->
        true

      # Must have both users
      is_nil(viewer) || is_nil(profile_user) ->
        false

      # Active conversation (non-blocked)
      has_active_conversation?(viewer.id, profile_user.id) ->
        true

      # In today's spotlight (bidirectional)
      in_todays_spotlight?(viewer.id, profile_user.id) ->
        true

      true ->
        false
    end
  end

  @doc """
  Returns the next Berlin midnight as a UTC DateTime.
  Used for the countdown timer.
  """
  def next_midnight_utc do
    {_start_utc, end_utc} = Timezone.berlin_today_utc_range()
    end_utc
  end

  @doc """
  Returns seconds until next Berlin midnight.
  """
  def seconds_until_midnight do
    next = next_midnight_utc()
    now = TimeMachine.utc_now()
    max(DateTime.diff(next, now, :second), 0)
  end

  @doc """
  Formats seconds as "Xh Ym" countdown string.
  """
  def format_countdown(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m"
      true -> "< 1m"
    end
  end

  # --- Private ---

  defp berlin_today do
    now_berlin =
      TimeMachine.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    DateTime.to_date(now_berlin)
  end

  defp load_today_entries(user_id, today) do
    SpotlightEntry
    |> where([e], e.user_id == ^user_id and e.shown_on == ^today)
    |> order_by([e], asc: e.is_wildcard, asc: e.inserted_at)
    |> Repo.all()
  end

  defp entries_to_users(entries) do
    user_ids = Enum.map(entries, & &1.shown_user_id)

    wildcard_ids =
      entries |> Enum.filter(& &1.is_wildcard) |> Enum.map(& &1.shown_user_id) |> MapSet.new()

    users =
      User
      |> where([u], u.id in ^user_ids)
      |> Repo.all()
      |> Repo.preload(:locations)

    # Preserve entry order
    users_by_id = Map.new(users, &{&1.id, &1})
    ordered_users = user_ids |> Enum.map(&Map.get(users_by_id, &1)) |> Enum.reject(&is_nil/1)

    {ordered_users, wildcard_ids}
  end

  defp load_spotlight_users(user_id, today) do
    entries = load_today_entries(user_id, today)
    entries_to_users(entries)
  end

  defp seed_daily(viewer, today) do
    # Permanent exclusions: dismissed users + conversation partners
    dismissed = Discovery.dismissed_ids(viewer.id)
    conversation_partners = Messaging.list_conversation_partner_ids(viewer.id)
    permanent_exclusions = MapSet.new(dismissed ++ conversation_partners)

    # Build candidate pool
    pool_candidates = SpotlightPool.build(viewer)
    pool_ids = Enum.map(pool_candidates, & &1.id)

    # Get current cycle number
    current_cycle = get_current_cycle(viewer.id)

    # Already shown in current cycle (non-wildcard entries from previous days)
    already_shown = already_shown_in_cycle(viewer.id, current_cycle)

    # Available = pool - permanent exclusions - already shown
    available = filter_available(pool_ids, permanent_exclusions, already_shown)

    {picks, new_cycle} =
      if length(available) < @pool_picks do
        # Cycle exhausted: increment cycle, clear history, recalculate
        new_cycle = current_cycle + 1
        clear_old_non_wildcard_entries(viewer.id)
        fresh_available = filter_available(pool_ids, permanent_exclusions, MapSet.new())
        {take_random(fresh_available, @pool_picks), new_cycle}
      else
        {take_random(available, @pool_picks), current_cycle}
      end

    # Wildcard picks from expanded pool
    wildcard_candidates = WildcardPool.build(viewer)
    wildcard_ids = Enum.map(wildcard_candidates, & &1.id)
    picks_set = MapSet.new(picks)

    wildcard_available =
      wildcard_ids
      |> Enum.reject(&(MapSet.member?(permanent_exclusions, &1) || MapSet.member?(picks_set, &1)))

    wildcard_picks = take_random(wildcard_available, @wildcard_picks)

    # Build insert rows
    now = TimeMachine.utc_now() |> DateTime.truncate(:second)

    pool_rows =
      Enum.map(picks, fn uid ->
        %{
          id: Ecto.UUID.generate(),
          user_id: viewer.id,
          shown_user_id: uid,
          shown_on: today,
          is_wildcard: false,
          cycle_number: new_cycle,
          inserted_at: now,
          updated_at: now
        }
      end)

    wildcard_rows =
      Enum.map(wildcard_picks, fn uid ->
        %{
          id: Ecto.UUID.generate(),
          user_id: viewer.id,
          shown_user_id: uid,
          shown_on: today,
          is_wildcard: true,
          cycle_number: new_cycle,
          inserted_at: now,
          updated_at: now
        }
      end)

    all_rows = pool_rows ++ wildcard_rows

    if all_rows != [] do
      Repo.insert_all(SpotlightEntry, all_rows, on_conflict: :nothing)
    end
  end

  defp get_current_cycle(user_id) do
    SpotlightEntry
    |> where([e], e.user_id == ^user_id and e.is_wildcard == false)
    |> select([e], max(e.cycle_number))
    |> Repo.one() || 0
  end

  defp already_shown_in_cycle(user_id, cycle_number) do
    SpotlightEntry
    |> where(
      [e],
      e.user_id == ^user_id and e.is_wildcard == false and e.cycle_number == ^cycle_number
    )
    |> select([e], e.shown_user_id)
    |> Repo.all()
    |> MapSet.new()
  end

  defp clear_old_non_wildcard_entries(user_id) do
    today = berlin_today()

    SpotlightEntry
    |> where([e], e.user_id == ^user_id and e.is_wildcard == false and e.shown_on != ^today)
    |> Repo.delete_all()
  end

  defp filter_available(pool_ids, permanent_exclusions, already_shown) do
    pool_ids
    |> Enum.reject(
      &(MapSet.member?(permanent_exclusions, &1) || MapSet.member?(already_shown, &1))
    )
  end

  defp take_random(list, n) do
    list |> Enum.shuffle() |> Enum.take(n)
  end

  defp has_active_conversation?(user1_id, user2_id) do
    case Messaging.get_conversation_by_participants(user1_id, user2_id) do
      nil -> false
      conversation -> !Messaging.blocked_in_conversation?(conversation.id, user1_id)
    end
  end

  defp in_todays_spotlight?(user1_id, user2_id) do
    today = berlin_today()

    SpotlightEntry
    |> where(
      [e],
      (e.user_id == ^user1_id and e.shown_user_id == ^user2_id and e.shown_on == ^today) or
        (e.user_id == ^user2_id and e.shown_user_id == ^user1_id and e.shown_on == ^today)
    )
    |> Repo.exists?()
  end
end
