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
  alias Animina.Discovery.Settings

  @impl true
  def filter_candidates(query, viewer, opts) do
    list_type = Keyword.get(opts, :list_type, "combined")

    query
    |> FilterHelpers.exclude_self(viewer)
    |> FilterHelpers.exclude_soft_deleted()
    |> FilterHelpers.filter_by_state()
    |> FilterHelpers.exclude_contact_blacklisted(viewer)
    |> filter_by_distance_relaxed(viewer)
    |> FilterHelpers.filter_by_bidirectional_gender(viewer)
    |> FilterHelpers.filter_by_bidirectional_age(viewer)
    |> FilterHelpers.filter_by_bidirectional_height(viewer)
    |> FilterHelpers.exclude_dismissed(viewer)
    |> FilterHelpers.exclude_closed_conversations(viewer)
    |> FilterHelpers.exclude_recently_shown(viewer, list_type)
    |> FilterHelpers.maybe_exclude_at_daily_limit()
  end

  # --- Unique to RelaxedFilter ---

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
end
