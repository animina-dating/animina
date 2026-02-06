defmodule Animina.Discovery.Scorers.WeightedScorer do
  @moduledoc """
  Default scoring algorithm that weights flag matches by category importance.

  Scores are computed using configurable weights from feature flags,
  with category multipliers applied to make certain categories (e.g., Languages)
  more influential in the final score.

  All flags use fixed system defaults (green soft: +10, red soft: -50).
  """

  @behaviour Animina.Discovery.Behaviours.Scorer

  alias Animina.Discovery.{Popularity, Settings}
  alias Animina.Repo
  alias Animina.Traits.Flag

  import Ecto.Query

  @impl true
  def compute_combined_score(_viewer, candidate, overlap) do
    base_score = 0

    # Red penalties (soft red only - hard red is excluded by filter)
    red_penalty =
      compute_category_weighted_score(
        overlap.red_white_soft,
        Settings.soft_red_penalty()
      )

    # Green bonuses (soft only - hard green is excluded by filter)
    green_soft_bonus =
      compute_category_weighted_score(
        overlap.green_white_soft,
        Settings.green_soft_bonus()
      )

    # White-white bonus
    white_bonus =
      compute_category_weighted_score(overlap.white_white, Settings.white_white_bonus())

    # Profile bonuses/penalties
    new_user_bonus = if Settings.new_user?(candidate), do: Settings.new_user_boost(), else: 0

    incomplete_penalty =
      if Settings.complete_profile?(candidate), do: 0, else: Settings.incomplete_penalty()

    popularity_adjustment = compute_popularity_adjustment(candidate)

    base_score + red_penalty + green_soft_bonus + white_bonus + new_user_bonus +
      incomplete_penalty + popularity_adjustment
  end

  @impl true
  def compute_safe_score(_viewer, candidate, overlap) do
    # Safe list has no red matches, so only count positives
    base_score = 0

    # Green bonuses (soft only - hard green is excluded by filter)
    green_soft_bonus =
      compute_category_weighted_score(
        overlap.green_white_soft,
        Settings.green_soft_bonus()
      )

    white_bonus =
      compute_category_weighted_score(overlap.white_white, Settings.white_white_bonus())

    new_user_bonus = if Settings.new_user?(candidate), do: Settings.new_user_boost(), else: 0

    incomplete_penalty =
      if Settings.complete_profile?(candidate), do: 0, else: Settings.incomplete_penalty()

    popularity_adjustment = compute_popularity_adjustment(candidate)

    base_score + green_soft_bonus + white_bonus + new_user_bonus +
      incomplete_penalty + popularity_adjustment
  end

  @impl true
  def compute_attracted_score(_viewer, candidate, overlap) do
    # Attracted list prioritizes green matches with double weight
    base_score = 0

    # Double the green bonuses for attracted list (soft only - hard green is excluded by filter)
    green_soft_bonus =
      compute_category_weighted_score(
        overlap.green_white_soft,
        Settings.green_soft_bonus() * 2
      )

    new_user_bonus = if Settings.new_user?(candidate), do: Settings.new_user_boost(), else: 0

    incomplete_penalty =
      if Settings.complete_profile?(candidate), do: 0, else: Settings.incomplete_penalty()

    popularity_adjustment = compute_popularity_adjustment(candidate)

    base_score + green_soft_bonus + new_user_bonus + incomplete_penalty +
      popularity_adjustment
  end

  # --- Private Functions ---

  defp compute_popularity_adjustment(candidate) do
    if Settings.popularity_enabled?() do
      {avg_7, _avg_30} = Popularity.get_rolling_averages(candidate.id)

      cond do
        # Low popularity (< 1 inquiry/day avg) → bonus to increase visibility
        avg_7 < 1.0 -> Settings.popularity_score_bonus()
        # High popularity (> 4 inquiries/day avg) → penalty to balance exposure
        avg_7 > 4.0 -> Settings.popularity_score_penalty()
        # Normal range → no adjustment
        true -> 0
      end
    else
      0
    end
  end

  defp compute_category_weighted_score([], _default_base), do: 0

  defp compute_category_weighted_score(flag_ids, default_base) when is_list(flag_ids) do
    # Load flags with their categories to get category names for multipliers
    flags_with_categories = load_flags_with_categories(flag_ids)

    Enum.reduce(flags_with_categories, 0, fn flag, acc ->
      category_name = flag.category && flag.category.name
      cat_multiplier = Settings.category_multiplier(category_name)
      acc + default_base * cat_multiplier
    end)
  end

  defp load_flags_with_categories([]), do: []

  defp load_flags_with_categories(flag_ids) do
    from(f in Flag,
      where: f.id in ^flag_ids,
      preload: [:category]
    )
    |> Repo.all()
  end
end
