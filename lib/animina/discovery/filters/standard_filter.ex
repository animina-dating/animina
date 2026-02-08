defmodule Animina.Discovery.Filters.StandardFilter do
  @moduledoc """
  Default filter strategy that applies all configured filters.

  Filters applied in order:
  1. Exclude self
  2. Exclude soft-deleted users
  3. State filter (only normal, not waitlisted)
  4. Distance filter (haversine calculation)
  5. Bidirectional gender preference
  6. Bidirectional age range
  7. Bidirectional height range
  8. Exclude permanently dismissed users
  9. Exclude users shown within cooldown period
  10. Optionally exclude incomplete profiles
  11. Exclude users at daily inquiry limit (if popularity protection enabled)
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
    |> filter_by_distance(viewer)
    |> FilterHelpers.filter_by_bidirectional_gender(viewer)
    |> FilterHelpers.filter_by_bidirectional_age(viewer)
    |> FilterHelpers.filter_by_bidirectional_height(viewer)
    |> FilterHelpers.exclude_dismissed(viewer)
    |> FilterHelpers.exclude_closed_conversations(viewer)
    |> FilterHelpers.exclude_recently_shown(viewer, list_type)
    |> FilterHelpers.maybe_exclude_incomplete_profiles()
    |> FilterHelpers.maybe_exclude_at_daily_limit()
  end

  # --- Unique to StandardFilter ---

  defp filter_by_distance(query, viewer) do
    # Get viewer's primary location (position 1)
    case FilterHelpers.get_viewer_coordinates(viewer) do
      {:ok, lat, lon} ->
        radius = viewer.search_radius || Settings.default_search_radius()

        # Join with user_locations and cities to filter by distance
        # Using the PostgreSQL haversine_distance function we created
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
        # No viewer location, can't filter by distance - exclude all
        where(query, [u], false)
    end
  end
end
