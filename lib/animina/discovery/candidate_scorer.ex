defmodule Animina.Discovery.CandidateScorer do
  @moduledoc """
  Orchestrates candidate scoring using the configured scorer module.

  This module delegates to the scorer implementation selected via feature flags,
  allowing runtime switching between different scoring algorithms.
  """

  alias Animina.Discovery.Settings
  alias Animina.Photos
  alias Animina.Traits.Matching

  @doc """
  Scores candidates for the Combined list.

  Returns a list of {candidate, score, overlap} tuples sorted by score descending.
  """
  def score_for_combined(viewer, candidates) do
    scorer = Settings.scorer_module()

    candidates
    |> Enum.map(fn candidate ->
      candidate = maybe_load_photos(candidate)
      overlap = Matching.compute_flag_overlap(viewer, candidate)
      score = scorer.compute_combined_score(viewer, candidate, overlap)
      {candidate, score, overlap}
    end)
    |> Enum.sort_by(fn {_candidate, score, _overlap} -> score end, :desc)
  end

  @doc """
  Scores candidates for the Safe list.

  Returns a list of {candidate, score, overlap} tuples sorted by score descending.
  """
  def score_for_safe(viewer, candidates) do
    scorer = Settings.scorer_module()

    candidates
    |> Enum.map(fn candidate ->
      candidate = maybe_load_photos(candidate)
      overlap = Matching.compute_flag_overlap(viewer, candidate)
      score = scorer.compute_safe_score(viewer, candidate, overlap)
      {candidate, score, overlap}
    end)
    |> Enum.sort_by(fn {_candidate, score, _overlap} -> score end, :desc)
  end

  @doc """
  Scores candidates for the Attracted list.

  Returns a list of {candidate, score, overlap} tuples sorted by score descending.
  """
  def score_for_attracted(viewer, candidates) do
    scorer = Settings.scorer_module()

    candidates
    |> Enum.map(fn candidate ->
      candidate = maybe_load_photos(candidate)
      overlap = Matching.compute_flag_overlap(viewer, candidate)
      score = scorer.compute_attracted_score(viewer, candidate, overlap)
      {candidate, score, overlap}
    end)
    |> Enum.sort_by(fn {_candidate, score, _overlap} -> score end, :desc)
  end

  # Load photos to determine profile completeness
  defp maybe_load_photos(%{photos: photos} = candidate) when is_list(photos) do
    candidate
  end

  defp maybe_load_photos(candidate) do
    photos = Photos.list_photos("user", candidate.id)
    Map.put(candidate, :photos, photos)
  end
end
