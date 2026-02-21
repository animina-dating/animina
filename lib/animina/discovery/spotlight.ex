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
  alias Animina.Photos
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Utils.Timezone

  @pool_picks 6
  @wildcard_picks 2
  @preview_count 4

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
        seed_tomorrow(viewer, today)
        load_spotlight_users(viewer.id, today)

      entries ->
        validate_and_repair_entries(viewer, entries, today)
        seed_tomorrow(viewer, today)
        load_spotlight_users(viewer.id, today)
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
    owner?(viewer, profile_user) ||
      staff?(scope) ||
      (both_present?(viewer, profile_user) &&
         connected?(viewer.id, profile_user.id))
  end

  defp owner?(viewer, profile_user) do
    viewer != nil && profile_user != nil && viewer.id == profile_user.id
  end

  defp staff?(scope), do: Scope.admin?(scope) || Scope.moderator?(scope)

  defp both_present?(viewer, profile_user) do
    viewer != nil && profile_user != nil
  end

  defp connected?(viewer_id, profile_user_id) do
    has_active_conversation?(viewer_id, profile_user_id) ||
      in_todays_spotlight?(viewer_id, profile_user_id)
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

  @doc """
  Returns up to 4 preview candidates from tomorrow's pre-seeded entries.

  These are genuine previews of tomorrow's spotlight, not random picks.
  Returns the first 4 non-wildcard entries by insertion order.
  """
  def preview_candidates(viewer) do
    tomorrow = Date.add(berlin_today(), 1)

    entries =
      SpotlightEntry
      |> where([e], e.user_id == ^viewer.id and e.shown_on == ^tomorrow)
      |> order_by([e], asc: e.is_wildcard, asc: e.inserted_at)
      |> limit(@preview_count)
      |> Repo.all()

    user_ids = Enum.map(entries, & &1.shown_user_id)

    users =
      User
      |> where([u], u.id in ^user_ids)
      |> Repo.all()
      |> Repo.preload(:locations)

    # Preserve entry order
    users_by_id = Map.new(users, &{&1.id, &1})
    user_ids |> Enum.map(&Map.get(users_by_id, &1)) |> Enum.reject(&is_nil/1)
  end

  @doc """
  Builds preview hint metadata for a list of preview candidates.

  Returns a list of maps with: id, pixelated_avatar_url, age, gender_symbol,
  city_name, obfuscated_name (first char + "...").
  """
  def build_preview_hints(users) do
    city_names = load_city_names_for_users(users)

    Enum.map(users, fn user ->
      %{
        id: user.id,
        pixelated_avatar_url: pixelated_avatar_url(user.id),
        age: Animina.Accounts.compute_age(user.birthday),
        gender_symbol: gender_symbol(user.gender),
        city_name: city_name_for_user(user, city_names),
        obfuscated_name: obfuscate_name(user.display_name)
      }
    end)
  end

  # --- Private ---

  defp seed_tomorrow(viewer, today) do
    tomorrow = Date.add(today, 1)

    # Idempotent: skip if tomorrow already has entries
    existing =
      SpotlightEntry
      |> where([e], e.user_id == ^viewer.id and e.shown_on == ^tomorrow)
      |> Repo.aggregate(:count)

    if existing > 0 do
      :ok
    else
      permanent_exclusions = permanent_exclusion_set(viewer.id)

      # Today's entries to also exclude
      today_ids =
        load_today_entries(viewer.id, today)
        |> Enum.map(& &1.shown_user_id)
        |> MapSet.new()

      # Build pool and filter
      pool_candidates = SpotlightPool.build(viewer)
      pool_ids = Enum.map(pool_candidates, & &1.id)

      available =
        pool_ids
        |> Enum.reject(
          &(MapSet.member?(permanent_exclusions, &1) || MapSet.member?(today_ids, &1))
        )

      picks = take_random(available, @pool_picks)

      # Wildcard picks
      wildcard_candidates = WildcardPool.build(viewer)
      wildcard_ids = Enum.map(wildcard_candidates, & &1.id)
      picks_set = MapSet.new(picks)

      wildcard_available =
        wildcard_ids
        |> Enum.reject(
          &(MapSet.member?(permanent_exclusions, &1) ||
              MapSet.member?(today_ids, &1) ||
              MapSet.member?(picks_set, &1))
        )

      wildcard_picks = take_random(wildcard_available, @wildcard_picks)

      # Use today's cycle number (don't advance)
      current_cycle = get_current_cycle(viewer.id)
      now = TimeMachine.utc_now() |> DateTime.truncate(:second)

      pool_rows =
        Enum.map(picks, fn uid ->
          %{
            id: Ecto.UUID.generate(),
            user_id: viewer.id,
            shown_user_id: uid,
            shown_on: tomorrow,
            is_wildcard: false,
            cycle_number: current_cycle,
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
            shown_on: tomorrow,
            is_wildcard: true,
            cycle_number: current_cycle,
            inserted_at: now,
            updated_at: now
          }
        end)

      all_rows = pool_rows ++ wildcard_rows

      if all_rows != [] do
        Repo.insert_all(SpotlightEntry, all_rows, on_conflict: :nothing)
      end

      :ok
    end
  end

  defp validate_and_repair_entries(viewer, entries, today) do
    # Check each shown_user for validity (state still "normal", not soft-deleted)
    invalid_entry_ids =
      entries
      |> Enum.filter(fn entry ->
        user =
          User
          |> where([u], u.id == ^entry.shown_user_id)
          |> Repo.one()

        is_nil(user) || user.state != "normal" || user.deleted_at != nil
      end)
      |> Enum.map(& &1.id)

    if invalid_entry_ids != [] do
      # Delete invalid entries
      SpotlightEntry
      |> where([e], e.id in ^invalid_entry_ids)
      |> Repo.delete_all()

      # Get fresh picks to replace them
      replacement_count = length(invalid_entry_ids)
      permanent_exclusions = permanent_exclusion_set(viewer.id)

      existing_ids =
        entries
        |> Enum.reject(&(&1.id in invalid_entry_ids))
        |> Enum.map(& &1.shown_user_id)
        |> MapSet.new()

      pool_candidates = SpotlightPool.build(viewer)
      pool_ids = Enum.map(pool_candidates, & &1.id)

      available =
        pool_ids
        |> Enum.reject(
          &(MapSet.member?(permanent_exclusions, &1) || MapSet.member?(existing_ids, &1))
        )

      picks = take_random(available, replacement_count)
      current_cycle = get_current_cycle(viewer.id)
      now = TimeMachine.utc_now() |> DateTime.truncate(:second)

      rows =
        Enum.map(picks, fn uid ->
          %{
            id: Ecto.UUID.generate(),
            user_id: viewer.id,
            shown_user_id: uid,
            shown_on: today,
            is_wildcard: false,
            cycle_number: current_cycle,
            inserted_at: now,
            updated_at: now
          }
        end)

      if rows != [] do
        Repo.insert_all(SpotlightEntry, rows, on_conflict: :nothing)
      end
    end
  end

  defp pixelated_avatar_url(user_id) do
    case Photos.get_user_avatar(user_id) do
      nil -> nil
      photo -> Photos.signed_url(photo, :pixel)
    end
  end

  defp gender_symbol("male"), do: "♂"
  defp gender_symbol("female"), do: "♀"
  defp gender_symbol(_), do: "○"

  defp obfuscate_name(nil), do: "?..."
  defp obfuscate_name(""), do: "?..."

  defp obfuscate_name(name) do
    first = String.first(name)
    "#{first}..."
  end

  defp city_name_for_user(user, city_names) do
    case user.locations do
      [%{zip_code: zip} | _] -> Map.get(city_names, zip)
      _ -> nil
    end
  end

  defp load_city_names_for_users(users) do
    users
    |> Enum.flat_map(fn user ->
      case user.locations do
        locations when is_list(locations) -> locations
        _ -> []
      end
    end)
    |> Animina.GeoData.city_names_for_locations()
  end

  defp berlin_today do
    now_berlin =
      TimeMachine.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    DateTime.to_date(now_berlin)
  end

  defp permanent_exclusion_set(viewer_id) do
    dismissed = Discovery.dismissed_ids(viewer_id)
    conversation_partners = Messaging.list_conversation_partner_ids(viewer_id)
    MapSet.new(dismissed ++ conversation_partners)
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
    permanent_exclusions = permanent_exclusion_set(viewer.id)

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
