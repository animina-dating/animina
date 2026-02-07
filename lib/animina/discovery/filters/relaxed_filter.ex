defmodule Animina.Discovery.Filters.RelaxedFilter do
  @moduledoc """
  Relaxed filter strategy with fewer restrictions.

  This filter is useful when:
  - User base is small and strict filtering returns too few results
  - Testing or development environments
  - Users who want to see more potential matches

  Differences from StandardFilter:
  - Distance filter is more lenient (2x the search radius)
  - Incomplete profiles are always included

  All gender, age, and height filters remain **bidirectional** — both sides
  must satisfy the other's preferences.
  """

  @behaviour Animina.Discovery.Behaviours.Filter

  import Ecto.Query

  alias Animina.Discovery.Filters.FilterHelpers
  alias Animina.Discovery.Popularity
  alias Animina.Discovery.Schemas.{Dismissal, SuggestionView}
  alias Animina.Discovery.Settings
  alias Animina.Messaging.Schemas.{ConversationClosure}
  alias Animina.TimeMachine

  @impl true
  def filter_candidates(query, viewer, opts) do
    list_type = Keyword.get(opts, :list_type, "combined")

    query
    |> exclude_self(viewer)
    |> exclude_soft_deleted()
    |> filter_by_state()
    |> filter_by_distance_relaxed(viewer)
    |> filter_by_bidirectional_gender(viewer)
    |> filter_by_bidirectional_age(viewer)
    |> filter_by_bidirectional_height(viewer)
    |> exclude_dismissed(viewer)
    |> exclude_closed_conversations(viewer)
    |> exclude_recently_shown(viewer, list_type)
    |> maybe_exclude_at_daily_limit()
  end

  # --- Individual Filters ---

  defp exclude_self(query, viewer) do
    where(query, [u], u.id != ^viewer.id)
  end

  defp exclude_soft_deleted(query) do
    where(query, [u], is_nil(u.deleted_at))
  end

  defp filter_by_state(query) do
    where(query, [u], u.state == "normal")
  end

  defp filter_by_distance_relaxed(query, viewer) do
    case FilterHelpers.get_viewer_coordinates(viewer) do
      {:ok, lat, lon} ->
        # Double the search radius for relaxed filter
        radius = (viewer.search_radius || Settings.default_search_radius()) * 2

        query
        |> join(:inner, [u], loc in assoc(u, :locations), on: loc.position == 1, as: :location)
        |> join(:inner, [u, location: loc], c in Animina.GeoData.City,
          on: c.zip_code == loc.zip_code,
          as: :city
        )
        |> where(
          [u, location: loc, city: c],
          fragment(
            "haversine_distance(?, ?, ?, ?) <= ?",
            ^lat,
            ^lon,
            c.lat,
            c.lon,
            ^radius
          )
        )

      :error ->
        where(query, [u], false)
    end
  end

  defp filter_by_bidirectional_gender(query, viewer) do
    viewer_gender = viewer.gender
    viewer_prefs = viewer.preferred_partner_gender || []

    query =
      if viewer_prefs == [] do
        query
      else
        where(query, [u], u.gender in ^viewer_prefs)
      end

    where(
      query,
      [u],
      fragment("cardinality(?) = 0", u.preferred_partner_gender) or
        fragment("? @> ARRAY[?]::varchar[]", u.preferred_partner_gender, ^viewer_gender)
    )
  end

  defp filter_by_bidirectional_age(query, viewer) do
    viewer_age = FilterHelpers.compute_age(viewer.birthday)

    if viewer_age do
      viewer_min_age = viewer_age - (viewer.partner_minimum_age_offset || 6)
      viewer_max_age = viewer_age + (viewer.partner_maximum_age_offset || 2)

      today = TimeMachine.utc_today()
      max_birthday = Date.add(today, -viewer_min_age * 365)
      min_birthday = Date.add(today, -viewer_max_age * 365)

      query
      # Candidate must be within viewer's age range
      |> where([u], u.birthday >= ^min_birthday and u.birthday <= ^max_birthday)
      # Viewer must be within candidate's age range (bidirectional)
      |> where(
        [u],
        fragment(
          "? >= (EXTRACT(YEAR FROM age(current_date, ?)) - COALESCE(?, 6))",
          ^viewer_age,
          u.birthday,
          u.partner_minimum_age_offset
        )
      )
      |> where(
        [u],
        fragment(
          "? <= (EXTRACT(YEAR FROM age(current_date, ?)) + COALESCE(?, 2))",
          ^viewer_age,
          u.birthday,
          u.partner_maximum_age_offset
        )
      )
    else
      query
    end
  end

  defp filter_by_bidirectional_height(query, viewer) do
    viewer_height = viewer.height
    viewer_min_height = viewer.partner_height_min || 80
    viewer_max_height = viewer.partner_height_max || 225

    if viewer_height do
      query
      # Candidate must be within viewer's height range
      |> where(
        [u],
        is_nil(u.height) or (u.height >= ^viewer_min_height and u.height <= ^viewer_max_height)
      )
      # Viewer must be within candidate's height range (bidirectional)
      |> where(
        [u],
        is_nil(u.partner_height_min) or ^viewer_height >= u.partner_height_min
      )
      |> where(
        [u],
        is_nil(u.partner_height_max) or ^viewer_height <= u.partner_height_max
      )
    else
      query
    end
  end

  defp exclude_dismissed(query, viewer) do
    dismissed_subquery =
      from(d in Dismissal,
        where: d.user_id == ^viewer.id,
        select: d.dismissed_id
      )

    where(query, [u], u.id not in subquery(dismissed_subquery))
  end

  defp exclude_closed_conversations(query, viewer) do
    closed_subquery =
      from(cc in ConversationClosure,
        where:
          (cc.closed_by_id == ^viewer.id or cc.other_user_id == ^viewer.id) and
            is_nil(cc.reopened_at),
        select:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            cc.closed_by_id,
            ^viewer.id,
            cc.other_user_id,
            cc.closed_by_id
          )
      )

    where(query, [u], u.id not in subquery(closed_subquery))
  end

  defp exclude_recently_shown(query, viewer, list_type) do
    cutoff = Settings.cooldown_cutoff_date()

    recently_shown_subquery =
      from(sv in SuggestionView,
        where: sv.viewer_id == ^viewer.id,
        where: sv.list_type == ^list_type,
        where: sv.shown_at > ^cutoff,
        select: sv.suggested_id
      )

    where(query, [u], u.id not in subquery(recently_shown_subquery))
  end

  defp maybe_exclude_at_daily_limit(query) do
    if Settings.popularity_enabled?() do
      users_at_limit = Popularity.users_exceeding_daily_limit()

      if Enum.empty?(users_at_limit) do
        query
      else
        where(query, [u], u.id not in ^users_at_limit)
      end
    else
      query
    end
  end
end
