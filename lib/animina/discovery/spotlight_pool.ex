defmodule Animina.Discovery.SpotlightPool do
  @moduledoc """
  Builds the spotlight pool — the base filtered set of potential matches.

  A flat filter pipeline with no scoring, no daily sets, and no cooldowns.
  All filters are bidirectional (both users must satisfy each other's constraints).
  Each filter step is a composable Ecto query pipe.

  ## Pipeline

      from(u in User)
      |> exclude_self(viewer)
      |> exclude_blacklisted(viewer)
      |> exclude_soft_deleted()
      |> filter_by_state()
      |> filter_by_distance(viewer)
      |> filter_by_gender(viewer)
      |> filter_by_age(viewer)
      |> filter_by_height(viewer)
      |> exclude_hard_red_conflicts(viewer)
      |> Repo.all()
  """

  import Ecto.Query

  alias Animina.Accounts.User
  alias Animina.Discovery.Filters.FilterHelpers
  alias Animina.Relationships
  alias Animina.Relationships.Schemas.{Relationship, RelationshipOverride}
  alias Animina.Repo
  alias Animina.Reports.ReportInvisibility
  alias Animina.Traits.UserFlag

  @doc """
  Main entry point. Returns a flat list of matching users.
  """
  def build(viewer) do
    viewer = ensure_locations_loaded(viewer)

    base_query()
    |> exclude_self(viewer)
    |> exclude_blacklisted(viewer)
    |> exclude_report_invisible(viewer)
    |> exclude_relationship_hidden(viewer)
    |> exclude_soft_deleted()
    |> filter_by_state()
    |> filter_by_distance(viewer)
    |> filter_by_gender(viewer)
    |> filter_by_age(viewer)
    |> filter_by_height(viewer)
    |> exclude_hard_red_conflicts(viewer)
    |> Repo.all()
  end

  @doc """
  Returns `{funnel_steps, candidates}` with per-step counts for admin diagnostics.

  Each step is `%{name: string, count: integer, drop: integer, drop_pct: float}`.
  """
  def build_with_funnel(viewer) do
    viewer = ensure_locations_loaded(viewer)

    steps = [
      {"All active users",
       fn _q ->
         base_query() |> exclude_soft_deleted() |> filter_by_state()
       end},
      {"− Self", &exclude_self(&1, viewer)},
      {"− Blacklisted", &exclude_blacklisted(&1, viewer)},
      {"− Report invisible", &exclude_report_invisible(&1, viewer)},
      {"− Relationship hidden", &exclude_relationship_hidden(&1, viewer)},
      {"− Distance", &filter_by_distance(&1, viewer)},
      {"− Gender", &filter_by_gender(&1, viewer)},
      {"− Age", &filter_by_age(&1, viewer)},
      {"− Height", &filter_by_height(&1, viewer)},
      {"− Hard-red conflicts", &exclude_hard_red_conflicts(&1, viewer)}
    ]

    {funnel, final_query} =
      Enum.reduce(steps, {[], nil}, fn {name, filter_fn}, {acc, prev_query} ->
        query =
          case prev_query do
            nil -> filter_fn.(nil)
            q -> filter_fn.(q)
          end

        count = Repo.aggregate(query, :count)

        prev_count =
          case acc do
            [] -> count
            [last | _] -> last.count
          end

        drop = prev_count - count
        drop_pct = if prev_count > 0, do: drop / prev_count * 100.0, else: 0.0

        step = %{name: name, count: count, drop: drop, drop_pct: drop_pct}
        {[step | acc], query}
      end)

    candidates = Repo.all(final_query)
    {Enum.reverse(funnel), candidates}
  end

  @doc """
  Returns {pool_count, candidates} where pool_count is the number of users
  that pass through the distance filter (the area pool) and candidates are
  the final results after all filters. Runs exactly 2 SQL calls.
  """
  def build_with_pool_count(viewer) do
    viewer = ensure_locations_loaded(viewer)

    through_distance =
      base_query()
      |> exclude_self(viewer)
      |> exclude_blacklisted(viewer)
      |> exclude_report_invisible(viewer)
      |> exclude_relationship_hidden(viewer)
      |> exclude_soft_deleted()
      |> filter_by_state()
      |> filter_by_distance(viewer)

    pool_count = Repo.aggregate(through_distance, :count)

    candidates =
      through_distance
      |> filter_by_gender(viewer)
      |> filter_by_age(viewer)
      |> filter_by_height(viewer)
      |> exclude_hard_red_conflicts(viewer)
      |> Repo.all()

    {pool_count, candidates}
  end

  # --- Query helpers ---

  defp base_query, do: from(u in User)

  # --- Filter delegations ---

  defp exclude_self(query, viewer), do: FilterHelpers.exclude_self(query, viewer)
  defp exclude_soft_deleted(query), do: FilterHelpers.exclude_soft_deleted(query)
  defp filter_by_state(query), do: FilterHelpers.filter_by_state(query)

  defp exclude_blacklisted(query, viewer),
    do: FilterHelpers.exclude_contact_blacklisted(query, viewer)

  defp exclude_report_invisible(query, viewer) do
    hidden_ids =
      from(i in ReportInvisibility,
        where: i.user_id == ^viewer.id and not is_nil(i.hidden_user_id),
        select: i.hidden_user_id
      )

    where(query, [u], u.id not in subquery(hidden_ids))
  end

  # Excludes users where the relationship status says visible_in_discovery: false
  # AND the viewer hasn't overridden it to true.
  # Uses two subqueries to avoid UUID casting issues with fragments.
  defp exclude_relationship_hidden(query, viewer) do
    hidden_statuses = Relationships.hidden_in_discovery_statuses()

    # When viewer is user_a, the other user is user_b
    hidden_as_a =
      from(r in Relationship,
        left_join: o in RelationshipOverride,
        on: o.relationship_id == r.id and o.user_id == ^viewer.id,
        where:
          r.user_a_id == ^viewer.id and
            r.status in ^hidden_statuses and
            (is_nil(o.visible_in_discovery) or o.visible_in_discovery == false),
        select: r.user_b_id
      )

    # When viewer is user_b, the other user is user_a
    hidden_as_b =
      from(r in Relationship,
        left_join: o in RelationshipOverride,
        on: o.relationship_id == r.id and o.user_id == ^viewer.id,
        where:
          r.user_b_id == ^viewer.id and
            r.status in ^hidden_statuses and
            (is_nil(o.visible_in_discovery) or o.visible_in_discovery == false),
        select: r.user_a_id
      )

    query
    |> where([u], u.id not in subquery(hidden_as_a))
    |> where([u], u.id not in subquery(hidden_as_b))
  end

  defp filter_by_gender(query, viewer),
    do: FilterHelpers.filter_by_bidirectional_gender(query, viewer)

  defp filter_by_age(query, viewer), do: FilterHelpers.filter_by_bidirectional_age(query, viewer)

  defp filter_by_height(query, viewer),
    do: FilterHelpers.filter_by_bidirectional_height(query, viewer)

  # --- Bidirectional distance filter ---

  defp filter_by_distance(query, viewer) do
    case FilterHelpers.get_viewer_coordinates(viewer) do
      {:ok, lat, lon} ->
        viewer_radius = viewer.search_radius || 60
        default_radius = 60

        query
        |> join(:inner, [u], loc in assoc(u, :locations), on: loc.position == 1, as: :location)
        |> join(:inner, [u, location: loc], c in Animina.GeoData.City,
          on: c.zip_code == loc.zip_code,
          as: :city
        )
        |> where(
          [u, location: _loc, city: c],
          # Direction 1: candidate within viewer's radius
          # Direction 2: viewer within candidate's radius
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

  # --- Hard red conflict filter (SQL subqueries) ---

  defp exclude_hard_red_conflicts(query, viewer) do
    query
    |> exclude_viewer_hard_reds_vs_candidate_whites(viewer)
    |> exclude_candidate_hard_reds_vs_viewer_whites(viewer)
  end

  # Direction A: viewer's hard-red flags conflict with candidate's white flags
  defp exclude_viewer_hard_reds_vs_candidate_whites(query, viewer) do
    viewer_hard_red_flag_ids =
      from(uf in UserFlag,
        where: uf.user_id == ^viewer.id and uf.color == "red" and uf.intensity == "hard",
        select: uf.flag_id
      )

    conflicting_user_ids =
      from(uf in UserFlag,
        where: uf.color == "white" and uf.flag_id in subquery(viewer_hard_red_flag_ids),
        select: uf.user_id
      )

    where(query, [u], u.id not in subquery(conflicting_user_ids))
  end

  # Direction B: candidate's hard-red flags conflict with viewer's white flags
  defp exclude_candidate_hard_reds_vs_viewer_whites(query, viewer) do
    viewer_white_flag_ids =
      from(uf in UserFlag,
        where: uf.user_id == ^viewer.id and uf.color == "white",
        select: uf.flag_id
      )

    conflicting_user_ids =
      from(uf in UserFlag,
        where:
          uf.color == "red" and uf.intensity == "hard" and
            uf.flag_id in subquery(viewer_white_flag_ids),
        select: uf.user_id
      )

    where(query, [u], u.id not in subquery(conflicting_user_ids))
  end

  # --- Helpers ---

  defp ensure_locations_loaded(%{locations: %Ecto.Association.NotLoaded{}} = viewer) do
    Repo.preload(viewer, :locations)
  end

  defp ensure_locations_loaded(viewer), do: viewer
end
