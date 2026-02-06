defmodule Animina.Discovery.Settings do
  @moduledoc """
  Centralized access to all discovery feature flags.
  All parameters are stored in FunWithFlags for runtime configuration.
  """

  alias Animina.FeatureFlags

  # --- General Settings ---

  @doc """
  Returns the number of suggestions to show per list.
  Default: 8
  """
  def suggestions_per_list do
    FeatureFlags.discovery_suggestions_per_list()
  end

  @doc """
  Returns the cooldown period in days before a user can reappear.
  Default: 30
  """
  def cooldown_days do
    FeatureFlags.discovery_cooldown_days()
  end

  @doc """
  Returns the boost period in days for new users.
  Default: 14
  """
  def new_user_boost_days do
    FeatureFlags.discovery_new_user_boost_days()
  end

  @doc """
  Returns the default search radius in km.
  Default: 60
  """
  def default_search_radius do
    FeatureFlags.discovery_default_search_radius()
  end

  @doc """
  Returns the number of wildcard profiles to show on the discover page.
  Default: 2
  """
  def wildcard_count do
    FeatureFlags.discovery_wildcard_count()
  end

  # --- Scoring Weights ---

  @doc """
  Returns the score penalty per soft-red flag match.
  Default: -50
  """
  def soft_red_penalty do
    FeatureFlags.discovery_soft_red_penalty()
  end

  @doc """
  Returns the score bonus per hard green-white match.
  Default: 20
  """
  def green_hard_bonus do
    FeatureFlags.discovery_green_hard_bonus()
  end

  @doc """
  Returns the score bonus per soft green-white match.
  Default: 10
  """
  def green_soft_bonus do
    FeatureFlags.discovery_green_soft_bonus()
  end

  @doc """
  Returns the score bonus per shared white trait.
  Default: 5
  """
  def white_white_bonus do
    FeatureFlags.discovery_white_white_bonus()
  end

  @doc """
  Returns the score boost for new users.
  Default: 100
  """
  def new_user_boost do
    FeatureFlags.discovery_new_user_boost()
  end

  @doc """
  Returns the score penalty for incomplete profiles.
  Default: -30
  """
  def incomplete_penalty do
    FeatureFlags.discovery_incomplete_penalty()
  end

  # --- Category Multipliers ---

  @doc """
  Returns the score multiplier for a given category.
  Languages: 3x, Relationship Goals: 2x, Others: 1x
  """
  def category_multiplier(category_name) do
    FeatureFlags.discovery_category_multiplier(category_name)
  end

  # --- Algorithm Selection ---

  @doc """
  Returns the configured scorer module.
  Resolves the module name from feature flags.
  """
  def scorer_module do
    case FeatureFlags.discovery_scorer_module() do
      "weighted" -> Animina.Discovery.Scorers.WeightedScorer
      "simple" -> Animina.Discovery.Scorers.SimpleScorer
      _ -> Animina.Discovery.Scorers.WeightedScorer
    end
  end

  @doc """
  Returns the configured filter module.
  Resolves the module name from feature flags.
  """
  def filter_module do
    case FeatureFlags.discovery_filter_module() do
      "standard" -> Animina.Discovery.Filters.StandardFilter
      "relaxed" -> Animina.Discovery.Filters.RelaxedFilter
      _ -> Animina.Discovery.Filters.StandardFilter
    end
  end

  # --- Filter Options ---

  @doc """
  Returns whether incomplete profiles should be fully excluded.
  Default: false
  """
  def exclude_incomplete_profiles? do
    FeatureFlags.discovery_exclude_incomplete_profiles?()
  end

  @doc """
  Returns whether mutually bookmarked users should be excluded.
  Default: true
  """
  def require_mutual_bookmark_exclusion? do
    FeatureFlags.discovery_require_mutual_bookmark_exclusion?()
  end

  # --- Helper Functions ---

  @doc """
  Returns the cutoff date for the cooldown period.
  Users shown after this date are still in cooldown.
  """
  def cooldown_cutoff_date do
    DateTime.utc_now()
    |> DateTime.add(-cooldown_days(), :day)
    |> DateTime.truncate(:second)
  end

  @doc """
  Returns the cutoff date for the new user boost.
  Users registered after this date get the boost.
  """
  def new_user_cutoff_date do
    DateTime.utc_now()
    |> DateTime.add(-new_user_boost_days(), :day)
    |> DateTime.truncate(:second)
  end

  @doc """
  Checks if a user is considered "new" for scoring purposes.
  """
  def new_user?(user) do
    case user.inserted_at do
      nil -> false
      inserted_at -> DateTime.compare(inserted_at, new_user_cutoff_date()) == :gt
    end
  end

  @doc """
  Checks if a user has a complete profile (photo, height, gender).
  """
  def complete_profile?(user) do
    has_photo?(user) && has_height?(user) && has_gender?(user)
  end

  defp has_photo?(user) do
    case user do
      %{photos: photos} when is_list(photos) -> Enum.any?(photos)
      _ -> false
    end
  end

  defp has_height?(user) do
    is_integer(user.height) && user.height > 0
  end

  defp has_gender?(user) do
    user.gender in ["male", "female", "diverse"]
  end

  # --- Popularity Protection ---

  @doc """
  Returns whether popular user protection is enabled.
  Default: false
  """
  def popularity_enabled? do
    FeatureFlags.discovery_popularity_enabled?()
  end

  @doc """
  Returns the daily inquiry limit before a user is removed from discovery.
  Default: 6
  """
  def daily_inquiry_limit do
    FeatureFlags.discovery_daily_inquiry_limit()
  end

  @doc """
  Returns the score bonus for low-popularity users.
  Default: 10
  """
  def popularity_score_bonus do
    FeatureFlags.discovery_popularity_score_bonus()
  end

  @doc """
  Returns the score penalty for high-popularity users.
  Default: -15
  """
  def popularity_score_penalty do
    FeatureFlags.discovery_popularity_score_penalty()
  end
end
