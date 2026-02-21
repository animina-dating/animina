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
  alias Animina.Repo

  @doc """
  Returns a flat list of matching users with relaxed filters.
  """
  def build(viewer) do
    viewer = FilterHelpers.ensure_locations_loaded(viewer)

    from(u in User)
    |> FilterHelpers.exclude_self(viewer)
    |> FilterHelpers.exclude_contact_blacklisted(viewer)
    |> FilterHelpers.exclude_report_invisible(viewer)
    |> FilterHelpers.exclude_relationship_hidden(viewer)
    |> FilterHelpers.exclude_soft_deleted()
    |> FilterHelpers.filter_by_state()
    |> filter_by_expanded_distance(viewer)
    |> FilterHelpers.filter_by_bidirectional_gender(viewer)
    |> filter_by_expanded_age(viewer)
    |> Repo.all()
  end

  # Distance with viewer's radius expanded by 20%, candidate's radius as-is
  defp filter_by_expanded_distance(query, viewer) do
    viewer_radius = (viewer.search_radius || 60) * 1.2
    FilterHelpers.filter_by_bidirectional_distance(query, viewer, viewer_radius)
  end

  # Age with viewer's offsets expanded by 20%, candidate's offsets as-is
  defp filter_by_expanded_age(query, viewer) do
    viewer_min_offset = (viewer.partner_minimum_age_offset || 6) * 1.2
    viewer_max_offset = (viewer.partner_maximum_age_offset || 2) * 1.2
    FilterHelpers.filter_by_bidirectional_age(query, viewer, viewer_min_offset, viewer_max_offset)
  end
end
