defmodule Animina.Discovery.Scorers.SimpleScorer do
  @moduledoc """
  Simple scoring algorithm that counts flag matches without category weighting.

  This is a faster but less nuanced alternative to the weighted scorer.
  All flag matches are counted equally regardless of category.
  """

  @behaviour Animina.Discovery.Behaviours.Scorer

  alias Animina.Discovery.Settings

  @impl true
  def compute_combined_score(_viewer, candidate, overlap) do
    base_score = 0

    # Simple counts with base weights
    red_penalty = length(overlap.red_white_soft) * Settings.soft_red_penalty()
    green_hard_bonus = length(overlap.green_white_hard) * Settings.green_hard_bonus()
    green_soft_bonus = length(overlap.green_white_soft) * Settings.green_soft_bonus()
    white_bonus = length(overlap.white_white) * Settings.white_white_bonus()

    new_user_bonus = if Settings.new_user?(candidate), do: Settings.new_user_boost(), else: 0

    incomplete_penalty =
      if Settings.complete_profile?(candidate), do: 0, else: Settings.incomplete_penalty()

    base_score + red_penalty + green_hard_bonus + green_soft_bonus + white_bonus + new_user_bonus +
      incomplete_penalty
  end

  @impl true
  def compute_safe_score(_viewer, candidate, overlap) do
    base_score = 0

    green_hard_bonus = length(overlap.green_white_hard) * Settings.green_hard_bonus()
    green_soft_bonus = length(overlap.green_white_soft) * Settings.green_soft_bonus()
    white_bonus = length(overlap.white_white) * Settings.white_white_bonus()

    new_user_bonus = if Settings.new_user?(candidate), do: Settings.new_user_boost(), else: 0

    incomplete_penalty =
      if Settings.complete_profile?(candidate), do: 0, else: Settings.incomplete_penalty()

    base_score + green_hard_bonus + green_soft_bonus + white_bonus + new_user_bonus +
      incomplete_penalty
  end

  @impl true
  def compute_attracted_score(_viewer, candidate, overlap) do
    base_score = 0

    # Double the green bonuses for attracted list
    green_hard_bonus = length(overlap.green_white_hard) * Settings.green_hard_bonus() * 2
    green_soft_bonus = length(overlap.green_white_soft) * Settings.green_soft_bonus() * 2

    new_user_bonus = if Settings.new_user?(candidate), do: Settings.new_user_boost(), else: 0

    incomplete_penalty =
      if Settings.complete_profile?(candidate), do: 0, else: Settings.incomplete_penalty()

    base_score + green_hard_bonus + green_soft_bonus + new_user_bonus + incomplete_penalty
  end
end
