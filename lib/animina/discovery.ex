defmodule Animina.Discovery do
  @moduledoc """
  Context for partner discovery and suggestion generation.

  This module provides the main API for:
  - Generating partner suggestions across three lists (Combined, Safe, Attracted)
  - Managing user dismissals ("Not interested")
  - Tracking suggestion views for cooldown enforcement
  - Popular user protection (daily inquiry limits)
  - Cleaning up old records

  ## Three Lists

  - **Combined**: Smart scoring that balances red flag avoidance (higher weight)
    with green flag attraction. Soft-red matches are included but penalized
    and shown with warnings.

  - **Safe**: Only shows users with zero red flag matches (hard or soft).
    Best for users who want to avoid any potential conflicts.

  - **Attracted**: Prioritizes users matching the viewer's green flags.
    Best for users looking for specific traits they desire.

  ## Bidirectional Matching

  All suggestions are bidirectional - User A sees User B only if both users
  fit each other's criteria (gender, age, height, distance).

  ## Popular User Protection

  When enabled, popular users are protected from being overwhelmed:
  - Users who receive 6+ inquiries per day are temporarily hidden from discovery
  - Scoring adjustments boost low-popularity users and reduce high-popularity users
  - Rolling averages (7-day, 30-day) are computed nightly for scoring

  ## Configuration

  All parameters are configurable via FunWithFlags. See `Animina.Discovery.Settings`
  for the full list of configurable options.
  """

  import Ecto.Query

  alias Animina.Discovery.Popularity
  alias Animina.Discovery.Schemas.{Dismissal, ProfileVisit, SuggestionView}
  alias Animina.Discovery.{Settings, SuggestionGenerator}
  alias Animina.Repo

  # --- Suggestion Generation ---

  @doc """
  Generates suggestions for all three lists.

  Returns a map with `:combined`, `:safe`, and `:attracted` keys,
  each containing a list of suggestion maps.

  Each suggestion contains:
  - `:user` - The candidate user
  - `:score` - The computed match score
  - `:overlap` - The flag overlap data
  - `:list_type` - Which list this suggestion belongs to
  - `:has_soft_red` - Whether there are soft-red flag matches
  - `:soft_red_count` - Number of soft-red matches
  - `:green_count` - Number of green-white matches
  - `:white_white_count` - Number of shared white traits
  """
  defdelegate generate_suggestions(viewer), to: SuggestionGenerator, as: :generate_all

  @doc """
  Generates suggestions for the Combined list only.
  """
  defdelegate generate_combined_suggestions(viewer),
    to: SuggestionGenerator,
    as: :generate_combined

  @doc """
  Generates suggestions for the Safe list only.
  """
  defdelegate generate_safe_suggestions(viewer), to: SuggestionGenerator, as: :generate_safe

  @doc """
  Generates suggestions for the Attracted list only.
  """
  defdelegate generate_attracted_suggestions(viewer),
    to: SuggestionGenerator,
    as: :generate_attracted

  @doc """
  Generates wildcard suggestions — randomly picked from a relaxed pool.

  Wildcards use 20% wider search parameters and no flag scoring.
  Pass `exclude_ids` to skip users already shown in the combined list.
  """
  defdelegate generate_wildcards(viewer, exclude_ids \\ []),
    to: SuggestionGenerator,
    as: :generate_wildcards

  @doc """
  Records that suggestions were shown to a user.

  Call this after displaying suggestions to track the cooldown period.
  """
  defdelegate record_suggestion_views(viewer, suggestions),
    to: SuggestionGenerator,
    as: :record_views

  # --- Dismissals ---

  @doc """
  Dismisses a user permanently ("Not interested").

  The dismissed user will never appear in suggestions again for this viewer.
  """
  def dismiss_user(viewer, dismissed_user) do
    attrs = %{
      user_id: viewer.id,
      dismissed_id: dismissed_user.id
    }

    %Dismissal{}
    |> Dismissal.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :dismissed_id])
  end

  @doc """
  Dismisses a user by ID.
  """
  def dismiss_user_by_id(viewer_id, dismissed_id) do
    attrs = %{
      user_id: viewer_id,
      dismissed_id: dismissed_id
    }

    %Dismissal{}
    |> Dismissal.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :dismissed_id])
  end

  @doc """
  Checks if a user has been dismissed by the viewer.
  """
  def dismissed?(viewer_id, user_id) do
    Dismissal
    |> where([d], d.user_id == ^viewer_id and d.dismissed_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Returns the count of users dismissed by the viewer.
  """
  def dismissal_count(viewer_id) do
    Dismissal
    |> where([d], d.user_id == ^viewer_id)
    |> Repo.aggregate(:count)
  end

  # --- Suggestion Views ---

  @doc """
  Returns the count of unique users shown to the viewer across all lists.
  """
  def suggestion_view_count(viewer_id) do
    SuggestionView
    |> where([sv], sv.viewer_id == ^viewer_id)
    |> select([sv], count(sv.suggested_id, :distinct))
    |> Repo.one()
  end

  @doc """
  Checks if a user was shown recently (within cooldown period).
  """
  def recently_shown?(viewer_id, suggested_id, list_type) do
    cutoff = Settings.cooldown_cutoff_date()

    SuggestionView
    |> where([sv], sv.viewer_id == ^viewer_id)
    |> where([sv], sv.suggested_id == ^suggested_id)
    |> where([sv], sv.list_type == ^list_type)
    |> where([sv], sv.shown_at > ^cutoff)
    |> Repo.exists?()
  end

  # --- Cleanup ---

  @doc """
  Deletes suggestion view records older than the cooldown period.

  This should be run periodically to keep the table size manageable.
  """
  def cleanup_old_suggestion_views do
    cutoff = Settings.cooldown_cutoff_date()

    {count, _} =
      SuggestionView
      |> where([sv], sv.shown_at < ^cutoff)
      |> Repo.delete_all()

    {:ok, count}
  end

  # --- Settings Access ---

  @doc """
  Returns the current number of suggestions per list.
  """
  def suggestions_per_list do
    Settings.suggestions_per_list()
  end

  @doc """
  Returns the current cooldown period in days.
  """
  def cooldown_days do
    Settings.cooldown_days()
  end

  # --- Popularity Protection ---

  @doc """
  Records a first-contact inquiry from sender to receiver.

  Call this when a user initiates contact with another user (e.g., first message).
  Subsequent contacts between the same pair don't create new inquiries.
  """
  defdelegate record_inquiry(sender_id, receiver_id), to: Popularity

  @doc """
  Checks if an inquiry already exists from sender to receiver.
  """
  defdelegate inquiry_exists?(sender_id, receiver_id), to: Popularity

  @doc """
  Checks if a user has exceeded the daily inquiry limit.

  When true, the user should be temporarily removed from discovery.
  """
  defdelegate exceeded_daily_limit?(user_id), to: Popularity

  @doc """
  Returns whether popularity protection is enabled.
  """
  def popularity_enabled? do
    Settings.popularity_enabled?()
  end

  # --- Profile Visits ---

  @doc """
  Records a profile visit. Upserts so revisiting just updates the timestamp.
  """
  def record_profile_visit(visitor_id, visited_id) do
    attrs = %{visitor_id: visitor_id, visited_id: visited_id}

    %ProfileVisit{}
    |> ProfileVisit.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [updated_at: DateTime.utc_now(:second)]],
      conflict_target: [:visitor_id, :visited_id]
    )
  end

  @doc """
  Returns a MapSet of user IDs (from `candidate_ids`) that the visitor has visited.
  """
  def visited_profile_ids(visitor_id, candidate_ids) do
    ProfileVisit
    |> where([pv], pv.visitor_id == ^visitor_id and pv.visited_id in ^candidate_ids)
    |> select([pv], pv.visited_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Checks if the visitor has visited the given profile.
  """
  def has_visited_profile?(visitor_id, visited_id) do
    ProfileVisit
    |> where([pv], pv.visitor_id == ^visitor_id and pv.visited_id == ^visited_id)
    |> Repo.exists?()
  end
end
