defmodule Animina.Photos do
  @moduledoc """
  Context for managing photos.

  This module acts as a facade, delegating to specialized sub-modules:
  - `Animina.Photos.Appeals` - Appeal workflow for rejected photos
  - `Animina.Photos.AuditLog` - Audit logging for photo events
  - `Animina.Photos.Blacklist` - Perceptual hash blacklist management
  - `Animina.Photos.FileManagement` - File upload and validation
  - `Animina.Photos.OllamaQueue` - Ollama retry queue management
  - `Animina.Photos.UrlSigning` - Signed URL generation and verification
  """

  import Ecto.Query

  alias Animina.Photos.FileManagement
  alias Animina.Photos.Photo
  alias Animina.Repo

  # --- Configuration helpers ---

  defp config(key, default) do
    :animina
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  def upload_dir, do: config(:upload_dir, "uploads")
  def max_upload_size, do: config(:max_upload_size, 6_000_000)
  def max_dimension, do: config(:max_dimension, 1400)
  def webp_quality, do: config(:webp_quality, 80)
  def blacklist_hamming_threshold, do: config(:blacklist_hamming_threshold, 10)
  def thumbnail_dimension, do: config(:thumbnail_dimension, 500)
  def ollama_timeout, do: config(:ollama_timeout, 120_000)
  def ollama_model, do: Animina.FeatureFlags.ollama_model()
  def ollama_total_timeout, do: config(:ollama_total_timeout, 300_000)
  def ollama_circuit_breaker_threshold, do: config(:ollama_circuit_breaker_threshold, 3)
  def ollama_circuit_breaker_reset_ms, do: config(:ollama_circuit_breaker_reset_ms, 60_000)

  # States where the processed .webp file should exist and can be served
  @servable_states ~w(approved ollama_checking pending_ollama needs_manual_review no_face_error error appeal_pending appeal_rejected)

  # States for Ollama retry queue
  @ollama_pending_states ~w(pending_ollama)
  @ollama_queue_states @ollama_pending_states ++ ["needs_manual_review"]

  # Max retries before requiring manual review
  @max_ollama_retries 20

  def servable_states, do: @servable_states
  def ollama_pending_states, do: @ollama_pending_states
  def ollama_queue_states, do: @ollama_queue_states
  def max_ollama_retries, do: @max_ollama_retries
  def processed_file_available?(state), do: state in @servable_states

  @doc """
  Returns the list of configured Ollama instances with their settings.
  """
  def ollama_instances do
    case config(:ollama_instances, nil) do
      instances when is_list(instances) ->
        instances

      nil ->
        url = config(:ollama_url, "http://localhost:11434/api")
        timeout = ollama_timeout()
        [%{url: url, timeout: timeout, priority: 1}]
    end
  end

  # --- CRUD ---

  @doc """
  Creates a new photo record in `pending` state.
  """
  def create_photo(attrs) do
    %Photo{}
    |> Photo.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a photo by ID.
  """
  def get_photo(id), do: Repo.get(Photo, id)

  @doc """
  Gets a photo by ID, raising if not found.
  """
  def get_photo!(id), do: Repo.get!(Photo, id)

  @doc """
  Transitions a photo to a new state with optional attributes.
  """
  def transition_photo(%Photo{} = photo, new_state, attrs \\ %{}) do
    case Repo.get(Photo, photo.id) do
      nil ->
        {:error, :not_found}

      fresh_photo ->
        with {:ok, updated_photo} <-
               fresh_photo
               |> Photo.transition_changeset(new_state, attrs)
               |> Repo.update() do
          broadcast_state_change(updated_photo)
          {:ok, updated_photo}
        end
    end
  end

  defp broadcast_state_change(%Photo{} = photo) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      "photos:#{photo.owner_type}:#{photo.owner_id}",
      {:photo_state_changed, photo}
    )
  end

  @doc """
  Deletes a photo record and its files from disk.
  """
  def delete_photo(%Photo{} = photo) do
    with {:ok, photo} <- Repo.delete(photo) do
      FileManagement.delete_photo_files(photo)
      {:ok, photo}
    end
  end

  # --- Polymorphic queries ---

  @doc """
  Lists all approved photos for a given owner.
  """
  def list_photos(owner_type, owner_id) do
    Photo
    |> where([p], p.owner_type == ^owner_type and p.owner_id == ^owner_id)
    |> where([p], p.state == "approved")
    |> order_by([p], asc: p.position, asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists photos for a given owner filtered by type.
  """
  def list_photos(owner_type, owner_id, type) do
    Photo
    |> where(
      [p],
      p.owner_type == ^owner_type and p.owner_id == ^owner_id and p.type == ^type
    )
    |> where([p], p.state == "approved")
    |> order_by([p], asc: p.position, asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all photos for a given owner in any state.
  """
  def list_all_photos(owner_type, owner_id) do
    Photo
    |> where([p], p.owner_type == ^owner_type and p.owner_id == ^owner_id)
    |> order_by([p], asc: p.position, asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists photos in any of the given states.
  """
  def list_photos_by_states(states) when is_list(states) do
    Photo
    |> where([p], p.state in ^states)
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Counts photos for a given owner, optionally filtered by type.
  """
  def count_photos(owner_type, owner_id, type \\ nil) do
    Photo
    |> where([p], p.owner_type == ^owner_type and p.owner_id == ^owner_id)
    |> where([p], p.state == "approved")
    |> maybe_filter_by_type(type)
    |> Repo.aggregate(:count)
  end

  defp maybe_filter_by_type(query, nil), do: query
  defp maybe_filter_by_type(query, type), do: where(query, [p], p.type == ^type)

  # --- User avatar helpers ---

  @doc """
  Gets the approved avatar photo for a user, or nil if none exists.
  """
  def get_user_avatar(user_id) do
    Photo
    |> where([p], p.owner_type == "User" and p.owner_id == ^user_id and p.type == "avatar")
    |> where([p], p.state == "approved")
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets the signed URL for a user's avatar, or nil if no avatar exists.
  """
  def get_user_avatar_url(user_id) do
    case get_user_avatar(user_id) do
      nil -> nil
      photo -> signed_url(photo)
    end
  end

  @doc """
  Gets the most recent avatar photo for a user in any state.
  """
  def get_user_avatar_any_state(user_id) do
    Photo
    |> where([p], p.owner_type == "User" and p.owner_id == ^user_id and p.type == "avatar")
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Deletes all avatar photos for a user.

  Also unlinks from the pinned gallery item if one exists.
  """
  def delete_user_avatars(user_id) do
    # Unlink from pinned gallery item first
    Animina.Gallery.unlink_avatar_from_pinned_item(user_id)

    # Then delete the photos
    Photo
    |> where([p], p.owner_type == "User" and p.owner_id == ^user_id and p.type == "avatar")
    |> Repo.all()
    |> Enum.each(&delete_photo/1)
  end

  # --- Delegations to UrlSigning ---

  defdelegate url_secret_salt(), to: Animina.Photos.UrlSigning
  defdelegate signed_url(photo, variant \\ :main), to: Animina.Photos.UrlSigning
  defdelegate verify_signature(signature, photo_id), to: Animina.Photos.UrlSigning
  defdelegate compute_signature(photo_id), to: Animina.Photos.UrlSigning

  # --- Delegations to FileManagement ---

  defdelegate upload_photo(owner_type, owner_id, source_path, opts \\ []),
    to: Animina.Photos.FileManagement

  defdelegate validate_image_magic(file_path), to: Animina.Photos.FileManagement
  defdelegate original_path_dir(owner_type, owner_id), to: Animina.Photos.FileManagement
  defdelegate processed_dir(), to: Animina.Photos.FileManagement
  defdelegate processed_path_dir(owner_type, owner_id), to: Animina.Photos.FileManagement
  defdelegate processed_path(photo, variant \\ :main), to: Animina.Photos.FileManagement
  defdelegate original_path(photo), to: Animina.Photos.FileManagement
  defdelegate get_crop_data(photo), to: Animina.Photos.FileManagement
  defdelegate delete_crop_data(photo), to: Animina.Photos.FileManagement

  # --- Delegations to AuditLog ---

  defdelegate log_event(
                photo,
                event_type,
                actor_type,
                actor_id \\ nil,
                details \\ %{},
                opts \\ []
              ),
              to: Animina.Photos.AuditLog

  defdelegate get_photo_history(photo_id), to: Animina.Photos.AuditLog
  defdelegate list_recent_events(limit \\ 100), to: Animina.Photos.AuditLog

  # --- Delegations to Blacklist ---

  defdelegate compute_dhash(image_path), to: Animina.Photos.Blacklist
  defdelegate blacklist_dir(), to: Animina.Photos.Blacklist

  defdelegate add_to_blacklist(dhash, reason, added_by, source_photo \\ nil),
    to: Animina.Photos.Blacklist

  defdelegate remove_from_blacklist(entry), to: Animina.Photos.Blacklist
  defdelegate check_blacklist(dhash, threshold \\ nil), to: Animina.Photos.Blacklist
  defdelegate hamming_distance(hash1, hash2), to: Animina.Photos.Blacklist
  defdelegate get_blacklist_entry_by_dhash(dhash), to: Animina.Photos.Blacklist
  defdelegate get_blacklist_entry(id), to: Animina.Photos.Blacklist
  defdelegate list_blacklist_entries(), to: Animina.Photos.Blacklist
  defdelegate list_blacklist_entries_paginated(opts \\ []), to: Animina.Photos.Blacklist

  # --- Delegations to Appeals ---

  defdelegate create_appeal(photo, user, reason \\ nil), to: Animina.Photos.Appeals
  defdelegate list_pending_appeals(), to: Animina.Photos.Appeals
  defdelegate list_pending_appeals_paginated(opts \\ []), to: Animina.Photos.Appeals
  defdelegate count_pending_appeals(opts \\ []), to: Animina.Photos.Appeals

  defdelegate bulk_resolve_appeals(appeal_ids, reviewer, resolution, opts \\ []),
    to: Animina.Photos.Appeals

  defdelegate get_appeal(id), to: Animina.Photos.Appeals
  defdelegate get_appeal!(id), to: Animina.Photos.Appeals
  defdelegate resolve_appeal(appeal, reviewer, resolution, opts \\ []), to: Animina.Photos.Appeals
  defdelegate has_pending_appeal?(photo_id), to: Animina.Photos.Appeals

  # --- Delegations to OllamaQueue ---

  defdelegate list_ollama_queue(), to: Animina.Photos.OllamaQueue
  defdelegate list_ollama_queue_paginated(opts \\ []), to: Animina.Photos.OllamaQueue
  defdelegate count_ollama_queue(opts \\ []), to: Animina.Photos.OllamaQueue
  defdelegate list_photos_due_for_ollama_retry(limit \\ 10), to: Animina.Photos.OllamaQueue
  defdelegate calculate_next_retry_at(retry_count), to: Animina.Photos.OllamaQueue
  defdelegate queue_for_ollama_retry(photo), to: Animina.Photos.OllamaQueue
  defdelegate return_to_ollama_checking(photo), to: Animina.Photos.OllamaQueue
  defdelegate clear_ollama_retry_fields(photo), to: Animina.Photos.OllamaQueue
  defdelegate approve_from_ollama_queue(photo, reviewer), to: Animina.Photos.OllamaQueue

  defdelegate reject_from_ollama_queue(photo, reviewer, opts \\ []),
    to: Animina.Photos.OllamaQueue

  defdelegate retry_from_manual_review(photo, reviewer), to: Animina.Photos.OllamaQueue
  defdelegate get_oldest_ollama_queue_photo(), to: Animina.Photos.OllamaQueue
end
