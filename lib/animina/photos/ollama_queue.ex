defmodule Animina.Photos.OllamaQueue do
  @moduledoc """
  Ollama retry queue management for photo processing.

  Handles queuing, retry logic, and manual review for photos
  that need Ollama-based content analysis.
  """

  import Ecto.Query

  alias Animina.Photos
  alias Animina.Photos.AuditLog
  alias Animina.Photos.Helpers
  alias Animina.Photos.Photo
  alias Animina.Repo

  @doc """
  Lists photos in the Ollama retry queue (pending_ollama and needs_manual_review states).
  Ordered by oldest first.
  """
  def list_ollama_queue do
    Photo
    |> where([p], p.state in ^Photos.ollama_queue_states())
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists photos in the Ollama retry queue with pagination.

  ## Options

    * `:page` - page number (default: 1)
    * `:per_page` - items per page (default: 50)
    * `:state_filter` - filter by specific state (nil for all queue states)
  """
  def list_ollama_queue_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1) |> max(1)
    per_page = Keyword.get(opts, :per_page, 50) |> max(1) |> min(250)
    state_filter = Keyword.get(opts, :state_filter)

    states =
      if state_filter && state_filter in Photos.ollama_queue_states() do
        [state_filter]
      else
        Photos.ollama_queue_states()
      end

    base_query =
      Photo
      |> where([p], p.state in ^states)

    total_count = Repo.aggregate(base_query, :count)
    total_pages = max(1, ceil(total_count / per_page))

    entries =
      base_query
      |> order_by([p], asc: p.ollama_retry_at, asc: p.inserted_at)
      |> offset(^((page - 1) * per_page))
      |> limit(^per_page)
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Counts photos in the Ollama retry queue.

  ## Options

    * `:state_filter` - filter by specific state (nil for all queue states)
  """
  def count_ollama_queue(opts \\ []) do
    state_filter = Keyword.get(opts, :state_filter)

    states =
      if state_filter && state_filter in Photos.ollama_queue_states() do
        [state_filter]
      else
        Photos.ollama_queue_states()
      end

    Photo
    |> where([p], p.state in ^states)
    |> Repo.aggregate(:count)
  end

  @doc """
  Finds photos due for Ollama retry (ollama_retry_at <= now).
  Returns up to `limit` photos ordered by retry time.
  """
  def list_photos_due_for_ollama_retry(limit \\ 10) do
    now = DateTime.utc_now()

    Photo
    |> where([p], p.state in ^Photos.ollama_pending_states())
    |> where([p], p.ollama_retry_at <= ^now)
    |> order_by([p], asc: p.ollama_retry_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Calculates the next retry time using the backoff formula: 15 * retry_count minutes.
  """
  def calculate_next_retry_at(retry_count) do
    minutes = 15 * retry_count
    DateTime.utc_now() |> DateTime.add(minutes, :minute)
  end

  @doc """
  Queues a photo for Ollama retry.

  Sets the photo to pending_ollama state with:
  - retry_count incremented
  - retry_at set based on backoff formula
  - bumblebee_score stored for context

  If retry_count reaches max_ollama_retries, transitions to needs_manual_review instead.
  """
  def queue_for_ollama_retry(%Photo{} = photo, bumblebee_score) do
    current_count = photo.ollama_retry_count || 0
    new_count = current_count + 1

    if new_count > Photos.max_ollama_retries() do
      AuditLog.log_event(photo, "ollama_retries_exhausted", "system", nil, %{
        retry_count: current_count,
        bumblebee_score: bumblebee_score
      })

      Photos.transition_photo(photo, "needs_manual_review", %{
        ollama_retry_count: new_count,
        ollama_retry_at: nil,
        ollama_check_type: nil,
        ollama_bumblebee_score: bumblebee_score
      })
    else
      next_retry_at = calculate_next_retry_at(new_count)

      AuditLog.log_event(photo, "ollama_retry_queued", "system", nil, %{
        retry_count: new_count,
        next_retry_at: next_retry_at,
        bumblebee_score: bumblebee_score
      })

      Photos.transition_photo(photo, "pending_ollama", %{
        ollama_retry_count: new_count,
        ollama_retry_at: next_retry_at,
        ollama_check_type: nil,
        ollama_bumblebee_score: bumblebee_score
      })
    end
  end

  @doc """
  Returns a photo from pending_ollama state back to the checking state for retry.
  """
  def return_to_ollama_checking(%Photo{state: "pending_ollama"} = photo) do
    Photos.transition_photo(photo, "ollama_checking")
  end

  def return_to_ollama_checking(%Photo{} = _photo) do
    {:error, :invalid_state}
  end

  @doc """
  Clears Ollama retry fields when a photo completes processing.
  """
  def clear_ollama_retry_fields(%Photo{} = photo) do
    photo
    |> Ecto.Changeset.change(%{
      ollama_retry_count: 0,
      ollama_retry_at: nil,
      ollama_check_type: nil,
      ollama_bumblebee_score: nil
    })
    |> Repo.update()
  end

  @doc """
  Admin action: Approve a photo from the Ollama queue.
  """
  def approve_from_ollama_queue(%Photo{} = photo, reviewer) do
    actor_type = Helpers.determine_actor_type(reviewer)

    AuditLog.log_event(photo, "manual_review_approved", actor_type, reviewer.id, %{
      previous_state: photo.state,
      check_type: photo.ollama_check_type,
      bumblebee_score: photo.ollama_bumblebee_score
    })

    with {:ok, photo} <- Photos.transition_photo(photo, "approved") do
      clear_ollama_retry_fields(photo)
    end
  end

  @doc """
  Admin action: Reject a photo from the Ollama queue.
  """
  def reject_from_ollama_queue(%Photo{} = photo, reviewer, opts \\ []) do
    add_to_blacklist = Keyword.get(opts, :add_to_blacklist, false)
    blacklist_reason = Keyword.get(opts, :blacklist_reason)
    actor_type = Helpers.determine_actor_type(reviewer)

    AuditLog.log_event(photo, "manual_review_rejected", actor_type, reviewer.id, %{
      previous_state: photo.state,
      check_type: photo.ollama_check_type,
      bumblebee_score: photo.ollama_bumblebee_score
    })

    with {:ok, photo} <-
           Photos.transition_photo(photo, "error", %{error_message: "Rejected by admin"}),
         {:ok, photo} <- clear_ollama_retry_fields(photo),
         :ok <-
           Helpers.maybe_add_to_blacklist(
             photo,
             add_to_blacklist,
             blacklist_reason,
             reviewer,
             actor_type
           ) do
      {:ok, photo}
    end
  end

  @doc """
  Admin action: Send a photo back to Ollama retry queue.
  """
  def retry_from_manual_review(%Photo{state: "needs_manual_review"} = photo, reviewer) do
    actor_type = Helpers.determine_actor_type(reviewer)

    AuditLog.log_event(photo, "manual_review_retry", actor_type, reviewer.id, %{})

    Photos.transition_photo(photo, "pending_ollama", %{
      ollama_retry_count: 0,
      ollama_retry_at: DateTime.utc_now()
    })
  end

  def retry_from_manual_review(%Photo{} = _photo, _reviewer) do
    {:error, :invalid_state}
  end

  @doc """
  Gets the oldest photo in the Ollama queue for display.
  """
  def get_oldest_ollama_queue_photo do
    Photo
    |> where([p], p.state in ^Photos.ollama_queue_states())
    |> order_by([p], asc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
