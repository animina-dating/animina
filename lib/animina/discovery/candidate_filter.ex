defmodule Animina.Discovery.CandidateFilter do
  @moduledoc """
  Orchestrates candidate filtering using the configured filter module.

  This module delegates to the filter implementation selected via feature flags,
  allowing runtime switching between different filter strategies.
  """

  import Ecto.Query

  alias Animina.Accounts.User
  alias Animina.Discovery.Settings
  alias Animina.Repo
  alias Animina.Traits
  alias Animina.Traits.Matching

  @doc """
  Returns a base query for candidate users.
  """
  def base_query do
    from(u in User, as: :user)
  end

  @doc """
  Filters candidates using the configured filter module.

  Options:
  - `:list_type` - The type of list being generated ("combined", "safe", "attracted")
  """
  def filter_candidates(query, viewer, opts \\ []) do
    filter_module = Settings.filter_module()
    filter_module.filter_candidates(query, viewer, opts)
  end

  @doc """
  Returns filtered candidates as a list, preloading necessary associations.
  """
  def get_filtered_candidates(viewer, opts \\ []) do
    base_query()
    |> filter_candidates(viewer, opts)
    |> preload([:locations])
    |> Repo.all()
  end

  @doc """
  Filters candidates for the Combined list (includes soft-red, excludes hard-red).
  """
  def filter_for_combined(viewer) do
    get_filtered_candidates(viewer, list_type: "combined")
    |> filter_by_hard_red(viewer)
    |> filter_by_hard_green(viewer)
  end

  @doc """
  Filters candidates for the Safe list (no red flags at all).
  """
  def filter_for_safe(viewer) do
    get_filtered_candidates(viewer, list_type: "safe")
    |> filter_by_any_red(viewer)
    |> filter_by_hard_green(viewer)
  end

  @doc """
  Filters candidates for the Attracted list (excludes hard-red).
  """
  def filter_for_attracted(viewer) do
    get_filtered_candidates(viewer, list_type: "attracted")
    |> filter_by_hard_red(viewer)
    |> filter_by_hard_green(viewer)
  end

  # --- Flag Filtering ---

  # These filters need to be done in-memory because they require
  # computing flag overlap which involves complex trait matching

  defp filter_by_hard_red(candidates, viewer) do
    Enum.reject(candidates, fn candidate ->
      overlap = Matching.compute_flag_overlap(viewer, candidate)
      overlap.red_white_hard != []
    end)
  end

  defp filter_by_any_red(candidates, viewer) do
    Enum.reject(candidates, fn candidate ->
      overlap = Matching.compute_flag_overlap(viewer, candidate)
      overlap.red_white != []
    end)
  end

  @doc """
  Filters candidates by the viewer's green-hard (required) flags.

  For each of the viewer's non-inherited green-hard flags, the candidate must
  have at least one white flag matching the requirement. When a parent flag is
  green-hard, its inherited children form a group — the candidate needs at least
  one match within each group (OR within group, AND across groups).

  Returns only candidates who satisfy ALL requirements.
  """
  def filter_by_hard_green(candidates, viewer) do
    requirements = build_green_hard_requirements(viewer)

    if requirements == [] do
      candidates
    else
      Enum.filter(candidates, &candidate_meets_requirements?(&1, requirements))
    end
  end

  defp candidate_meets_requirements?(candidate, requirements) do
    white_ids = candidate_white_flag_ids(candidate)
    Enum.all?(requirements, &has_overlap?(&1, white_ids))
  end

  defp has_overlap?(required_ids, white_ids) do
    MapSet.size(MapSet.intersection(required_ids, white_ids)) > 0
  end

  # Build requirement groups from viewer's green-hard flags.
  # Each non-inherited green-hard flag becomes a requirement.
  # The requirement is a MapSet of {flag_id, inherited children flag_ids}.
  defp build_green_hard_requirements(viewer) do
    viewer_flags = Traits.list_all_user_flags(viewer)

    viewer_flags
    |> Enum.filter(&(&1.color == "green" && &1.intensity == "hard" && !&1.inherited))
    |> Enum.map(fn uf ->
      # The flag itself plus any inherited children
      inherited_ids =
        viewer_flags
        |> Enum.filter(&(&1.source_flag_id == uf.flag_id && &1.inherited))
        |> Enum.map(& &1.flag_id)

      MapSet.new([uf.flag_id | inherited_ids])
    end)
  end

  defp candidate_white_flag_ids(candidate) do
    candidate
    |> Traits.list_all_user_flags()
    |> Enum.filter(&(&1.color == "white"))
    |> Enum.map(& &1.flag_id)
    |> MapSet.new()
  end
end
