defmodule Animina.Discovery do
  @moduledoc """
  Context for partner discovery.

  This module provides the public API for:
  - Managing user dismissals ("Not interested")
  - Tracking profile visits
  - Popular user protection (daily inquiry limits)
  """

  import Ecto.Query

  alias Animina.Discovery.Popularity
  alias Animina.Discovery.Schemas.{Dismissal, ProfileVisit}
  alias Animina.Repo
  alias Animina.TimeMachine

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

  # --- Profile Visits ---

  @doc """
  Records a profile visit. Upserts so revisiting just updates the timestamp.
  """
  def record_profile_visit(visitor_id, visited_id) do
    attrs = %{visitor_id: visitor_id, visited_id: visited_id}

    %ProfileVisit{}
    |> ProfileVisit.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [updated_at: TimeMachine.utc_now(:second)]],
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
