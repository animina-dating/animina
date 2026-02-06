defmodule Animina.Discovery.SuggestionGenerator do
  @moduledoc """
  Generates partner suggestions by combining filtering and scoring.

  This module orchestrates the full suggestion pipeline:
  1. Filter candidates using the configured filter strategy
  2. Apply red flag filtering (hard/soft depending on list type)
  3. Score remaining candidates
  4. Return top N suggestions per list
  """

  alias Animina.Discovery.{CandidateFilter, CandidateScorer, Settings}
  alias Animina.Discovery.Schemas.SuggestionView
  alias Animina.Repo

  @doc """
  Generates suggestions for all three lists.

  Returns a map with:
  - `:combined` - Smart scoring balancing red avoidance and green attraction
  - `:safe` - No red flag matches at all
  - `:attracted` - Green-flag-ranked suggestions

  Each list contains up to `suggestions_per_list` items (default 8).
  """
  def generate_all(viewer) do
    viewer = preload_viewer(viewer)

    %{
      "combined" => generate_combined(viewer),
      "safe" => generate_safe(viewer),
      "attracted" => generate_attracted(viewer)
    }
  end

  @doc """
  Generates the Combined list.

  Users with soft-red matches are included but penalized and marked with warnings.
  Hard-red matches are excluded entirely.
  """
  def generate_combined(viewer) do
    viewer = preload_viewer(viewer)
    limit = Settings.suggestions_per_list()
    candidates = CandidateFilter.filter_for_combined(viewer)

    candidates
    |> then(&CandidateScorer.score_for_combined(viewer, &1))
    |> Enum.take(limit)
    |> Enum.map(&to_suggestion(&1, "combined"))
  end

  @doc """
  Generates the Safe list.

  Only includes candidates with zero red flag matches (hard or soft).
  """
  def generate_safe(viewer) do
    viewer = preload_viewer(viewer)
    limit = Settings.suggestions_per_list()
    candidates = CandidateFilter.filter_for_safe(viewer)

    candidates
    |> then(&CandidateScorer.score_for_safe(viewer, &1))
    |> Enum.take(limit)
    |> Enum.map(&to_suggestion(&1, "safe"))
  end

  @doc """
  Generates the Attracted list.

  Prioritizes candidates matching the viewer's green flags.
  Hard-red matches are excluded.
  """
  def generate_attracted(viewer) do
    viewer = preload_viewer(viewer)
    limit = Settings.suggestions_per_list()
    candidates = CandidateFilter.filter_for_attracted(viewer)

    candidates
    |> then(&CandidateScorer.score_for_attracted(viewer, &1))
    |> Enum.take(limit)
    |> Enum.map(&to_suggestion(&1, "attracted"))
  end

  @doc """
  Generates wildcard suggestions — randomly picked from a relaxed pool.

  Parameters are widened by 20% (age offsets, height range, search radius)
  and no flag scoring or filtering is applied. Results are randomly shuffled.

  `exclude_ids` is a list of user IDs to skip (e.g. users already in the
  combined list).
  """
  def generate_wildcards(viewer, exclude_ids \\ []) do
    viewer = preload_viewer(viewer)
    count = Settings.wildcard_count()

    if count == 0 do
      []
    else
      relaxed_viewer = relax_preferences(viewer)

      CandidateFilter.get_filtered_candidates(relaxed_viewer, list_type: "combined")
      |> Enum.reject(fn candidate -> candidate.id in exclude_ids end)
      |> Enum.shuffle()
      |> Enum.take(count)
      |> Enum.map(&to_wildcard_suggestion/1)
    end
  end

  defp relax_preferences(viewer) do
    min_offset = viewer.partner_minimum_age_offset || 6
    max_offset = viewer.partner_maximum_age_offset || 2
    height_min = viewer.partner_height_min || 80
    height_max = viewer.partner_height_max || 225
    radius = viewer.search_radius || Settings.default_search_radius()

    %{
      viewer
      | partner_minimum_age_offset: min_offset + max(ceil(min_offset * 0.2), 1),
        partner_maximum_age_offset: max_offset + max(ceil(max_offset * 0.2), 1),
        partner_height_min: max(height_min - ceil((height_max - height_min) * 0.1), 50),
        partner_height_max: min(height_max + ceil((height_max - height_min) * 0.1), 250),
        search_radius: radius + max(ceil(radius * 0.2), 5)
    }
  end

  defp to_wildcard_suggestion(candidate) do
    %{
      user: candidate,
      score: 0,
      overlap: %{red_white_soft: [], green_white: [], white_white: []},
      list_type: "wildcard",
      has_soft_red: false,
      soft_red_count: 0,
      green_count: 0,
      white_white_count: 0,
      white_white_flag_ids: [],
      published_white_flags: []
    }
  end

  @doc """
  Records that suggestions were shown to a user.

  This updates the cooldown tracking so these users won't appear again
  until the cooldown period expires.
  """
  def record_views(viewer, suggestions) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(suggestions, fn suggestion ->
      attrs = %{
        viewer_id: viewer.id,
        suggested_id: suggestion.user.id,
        list_type: suggestion.list_type,
        shown_at: now
      }

      %SuggestionView{}
      |> SuggestionView.changeset(attrs)
      |> Repo.insert(
        on_conflict: {:replace, [:shown_at, :updated_at]},
        conflict_target: [:viewer_id, :suggested_id, :list_type]
      )
    end)
  end

  # --- Private Functions ---

  defp preload_viewer(viewer) do
    if Ecto.assoc_loaded?(viewer.locations) do
      viewer
    else
      Repo.preload(viewer, [:locations])
    end
  end

  defp to_suggestion({candidate, score, overlap}, list_type) do
    %{
      user: candidate,
      score: score,
      overlap: overlap,
      list_type: list_type,
      has_soft_red: overlap.red_white_soft != [],
      soft_red_count: length(overlap.red_white_soft),
      green_count: length(overlap.green_white),
      white_white_count: length(overlap.white_white),
      white_white_flag_ids: overlap.white_white
    }
  end
end
