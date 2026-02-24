defmodule Animina.Photos do
  @moduledoc """
  Context for managing photos.

  This module acts as a facade, delegating to specialized sub-modules:
  - `Animina.Photos.Appeals` - Appeal workflow for rejected photos
  - `Animina.Photos.AuditLog` - Audit logging for photo events
  - `Animina.Photos.Blacklist` - Perceptual hash blacklist management
  - `Animina.Photos.FileManagement` - File upload and validation
  - `Animina.Photos.OllamaQueue` - Photo review queue management (retry, manual review)
  - `Animina.Photos.UrlSigning` - Signed URL generation and verification
  """

  import Ecto.Query

  alias Animina.Photos.FileManagement
  alias Animina.Photos.Photo
  alias Animina.Repo
  alias Animina.TimeMachine

  # --- Configuration helpers ---

  defp config(key, default) do
    :animina
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  def upload_dir, do: config(:upload_dir, "uploads")

  def max_upload_size do
    Animina.FeatureFlags.photo_max_upload_size_mb() * 1_000_000
  end

  def max_dimension, do: config(:max_dimension, 1400)
  def webp_quality, do: config(:webp_quality, 80)
  def blacklist_hamming_threshold, do: config(:blacklist_hamming_threshold, 10)
  def thumbnail_dimension, do: config(:thumbnail_dimension, 768)
  def ollama_timeout, do: config(:ollama_timeout, 120_000)
  def ollama_model, do: Animina.FeatureFlags.ollama_model()

  # Model selection is now handled by Animina.AI.Executor

  # Kept for backward compatibility (used by OllamaQueue for adaptive retry logic)
  def select_ollama_model do
    alias Animina.FeatureFlags

    if FeatureFlags.enabled?(:ollama_adaptive_model) do
      queue_count = count_ollama_queue()
      downgrade_tier3 = FeatureFlags.ollama_downgrade_tier3_threshold()
      downgrade_tier2 = FeatureFlags.ollama_downgrade_tier2_threshold()
      upgrade = FeatureFlags.ollama_upgrade_threshold()

      cond do
        queue_count > downgrade_tier3 -> FeatureFlags.ollama_model_tier3()
        queue_count > downgrade_tier2 -> FeatureFlags.ollama_model_tier2()
        queue_count <= upgrade -> FeatureFlags.ollama_model_tier1()
        true -> FeatureFlags.ollama_model_tier2()
      end
    else
      ollama_model()
    end
  end

  def ollama_total_timeout, do: config(:ollama_total_timeout, 300_000)
  def ollama_circuit_breaker_threshold, do: config(:ollama_circuit_breaker_threshold, 3)
  def ollama_circuit_breaker_reset_ms, do: config(:ollama_circuit_breaker_reset_ms, 60_000)

  # States where the processed .webp file should exist and can be served
  @servable_states ~w(approved ollama_checking pending_ollama needs_manual_review no_face_error error appeal_pending appeal_rejected)

  # States where AI analysis is actively in progress
  @analyzing_states ~w(ollama_checking pending_ollama)

  # States for Ollama retry queue
  @ollama_pending_states ~w(pending_ollama)
  @ollama_queue_states @ollama_pending_states ++ ["needs_manual_review"]

  def servable_states, do: @servable_states
  def analyzing_states, do: @analyzing_states
  def ollama_pending_states, do: @ollama_pending_states
  def ollama_queue_states, do: @ollama_queue_states
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

  # --- Description generation ---

  @doc """
  Lists approved photos that don't have a description yet, oldest first.
  """
  def list_photos_needing_description(limit \\ 5) do
    Photo
    |> where([p], p.state == "approved" and is_nil(p.description))
    |> order_by([p], asc: p.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Counts approved photos that still need a description.
  """
  def count_photos_needing_description do
    Photo
    |> where([p], p.state == "approved" and is_nil(p.description))
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts all approved photos.
  """
  def count_approved_photos do
    Photo
    |> where([p], p.state == "approved")
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns all approved photo IDs.
  """
  def list_approved_photo_ids do
    Photo
    |> where([p], p.state == "approved")
    |> select([p], p.id)
    |> Repo.all()
  end

  @doc """
  Updates a photo's AI-generated description fields.
  """
  def update_photo_description(%Photo{} = photo, attrs) do
    photo
    |> Photo.description_changeset(attrs)
    |> Repo.update()
  end

  # --- Search ---

  @doc """
  Searches photos across user display_name, email, mobile_phone, and photo description.

  Returns a paginated result map with entries containing photo + owner info.

  ## Options

    * `:page` - Page number (default 1)
    * `:per_page` - Results per page (default 25)
    * `:state` - Filter by photo state (nil = all)
  """
  def search_photos(query, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 25)
    state = Keyword.get(opts, :state)
    search_term = "%#{query}%"

    base =
      from(p in Photo,
        join: u in Animina.Accounts.User,
        on: p.owner_type == "User" and p.owner_id == u.id,
        where:
          ilike(u.display_name, ^search_term) or
            ilike(u.email, ^search_term) or
            ilike(u.mobile_phone, ^search_term) or
            ilike(p.description, ^search_term),
        select: %{
          photo: p,
          user_display_name: u.display_name,
          user_email: u.email,
          user_id: u.id
        },
        order_by: [desc: p.inserted_at]
      )

    base = if state, do: where(base, [p], p.state == ^state), else: base

    total_count = Repo.aggregate(base, :count)
    total_pages = max(ceil(total_count / per_page), 1)
    offset = (page - 1) * per_page

    entries =
      base
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    %{
      entries: entries,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages
    }
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

  Accepts an optional `older_than_seconds` parameter to only return photos
  whose `updated_at` is older than the given threshold. This prevents
  recovering photos that are legitimately in-progress.
  """
  def list_photos_by_states(states, older_than_seconds \\ 0) when is_list(states) do
    query =
      Photo
      |> where([p], p.state in ^states)
      |> order_by([p], asc: p.inserted_at)

    query =
      if older_than_seconds > 0 do
        cutoff = DateTime.add(TimeMachine.utc_now(), -older_than_seconds, :second)
        where(query, [p], p.updated_at < ^cutoff)
      else
        query
      end

    Repo.all(query)
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

  Also unlinks from the pinned moodboard item if one exists.
  """
  def delete_user_avatars(user_id) do
    # Unlink from pinned moodboard item first
    Animina.Moodboard.unlink_avatar_from_pinned_item(user_id)

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
  defdelegate generate_pixel_variant(photo), to: Animina.Photos.FileManagement
  defdelegate generate_review_pixel_variant(photo), to: Animina.Photos.FileManagement

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

  # --- Seeding helpers ---

  @doc """
  Processes a photo for seeding without Ollama classification.

  This function:
  1. Processes the image (resize, convert to webp, create thumbnails)
  2. Transitions directly to approved state

  Used by development seeds to create photos without triggering Ollama.

  **Only available in :dev and :test environments.**
  """
  def process_for_seeding(%Photo{} = photo) do
    unless Mix.env() in [:dev, :test] do
      raise "process_for_seeding/1 is only available in development and test environments"
    end

    case original_path(photo) do
      {:ok, source_path} ->
        do_process_for_seeding(photo, source_path)

      {:error, _} ->
        {:error, :original_not_found}
    end
  end

  defp do_process_for_seeding(photo, source_path) do
    max_dim = max_dimension()
    thumb_dim = thumbnail_dimension()
    quality = webp_quality()

    # Create processed directory
    proc_dir = processed_path_dir(photo.owner_type, photo.owner_id)
    File.mkdir_p!(proc_dir)

    main_path = processed_path(photo, :main)
    thumbnail_path = processed_path(photo, :thumbnail)

    with {:ok, image} <- Image.open(source_path),
         {:ok, image} <- resize_to_max(image, max_dim),
         {:ok, _} <- Image.write(image, main_path, quality: quality, strip_metadata: true),
         {width, height} <- {Image.width(image), Image.height(image)},
         {:ok, thumb} <- resize_to_max(image, thumb_dim),
         {:ok, _} <- Image.write(thumb, thumbnail_path, quality: quality, strip_metadata: true) do
      # Transition directly to approved
      transition_photo(photo, "approved", %{width: width, height: height})
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resize_to_max(image, max_dim) do
    FileManagement.resize_to_max(image, max_dim)
  end
end
