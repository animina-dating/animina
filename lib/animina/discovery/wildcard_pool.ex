defmodule Animina.Discovery.WildcardPool do
  @moduledoc """
  Builds a relaxed candidate pool for wildcard spotlight picks.

  Uses the same base filters as SpotlightPool but with relaxed distance
  and age parameters, and without height or hard-red conflict filters.

  ## Relaxed filters
  - Distance: viewer's search_radius * 1.2, candidate's radius as-is
  - Age: viewer's offsets expanded by 20%, candidate's offsets as-is
  - Gender: bidirectional (same as SpotlightPool)
  - Height: NOT applied
  - Hard-red conflicts: NOT applied
  """

  import Ecto.Query

  alias Animina.Accounts.User
  alias Animina.Discovery.Filters.FilterHelpers
  alias Animina.GeoData
  alias Animina.Repo
  alias Animina.TimeMachine

  @doc """
  Returns a flat list of matching users with relaxed filters.
  """
  def build(viewer) do
    viewer = ensure_locations_loaded(viewer)

    from(u in User)
    |> FilterHelpers.exclude_self(viewer)
    |> FilterHelpers.exclude_contact_blacklisted(viewer)
    |> FilterHelpers.exclude_soft_deleted()
    |> FilterHelpers.filter_by_state()
    |> filter_by_expanded_distance(viewer)
    |> FilterHelpers.filter_by_bidirectional_gender(viewer)
    |> filter_by_expanded_age(viewer)
    |> Repo.all()
  end

  # Distance with viewer's radius expanded by 20%, candidate's radius as-is
  defp filter_by_expanded_distance(query, viewer) do
    case FilterHelpers.get_viewer_coordinates(viewer) do
      {:ok, lat, lon} ->
        viewer_radius = (viewer.search_radius || 60) * 1.2
        default_radius = 60

        query
        |> join(:inner, [u], loc in assoc(u, :locations), on: loc.position == 1, as: :location)
        |> join(:inner, [u, location: loc], c in GeoData.City,
          on: c.zip_code == loc.zip_code,
          as: :city
        )
        |> where(
          [u, location: _loc, city: c],
          fragment(
            "haversine_distance(?, ?, ?, ?) <= ?",
            ^lat,
            ^lon,
            c.lat,
            c.lon,
            ^viewer_radius
          ) and
            fragment(
              "haversine_distance(?, ?, ?, ?) <= COALESCE(?, ?)",
              ^lat,
              ^lon,
              c.lat,
              c.lon,
              u.search_radius,
              ^default_radius
            )
        )

      :error ->
        where(query, [u], false)
    end
  end

  # Age with viewer's offsets expanded by 20%, candidate's offsets as-is
  defp filter_by_expanded_age(query, viewer) do
    viewer_age = FilterHelpers.compute_age(viewer.birthday)

    if viewer_age do
      viewer_min_offset = (viewer.partner_minimum_age_offset || 6) * 1.2
      viewer_max_offset = (viewer.partner_maximum_age_offset || 2) * 1.2
      viewer_min_age = viewer_age - viewer_min_offset
      viewer_max_age = viewer_age + viewer_max_offset

      today = TimeMachine.utc_today()
      max_birthday = Date.add(today, -trunc(viewer_min_age * 365))
      min_birthday = Date.add(today, -trunc(viewer_max_age * 365))

      query
      |> where([u], u.birthday >= ^min_birthday and u.birthday <= ^max_birthday)
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

  defp ensure_locations_loaded(%{locations: %Ecto.Association.NotLoaded{}} = viewer) do
    Repo.preload(viewer, :locations)
  end

  defp ensure_locations_loaded(viewer), do: viewer
end
