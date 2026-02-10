defmodule Animina.Photos.Blacklist do
  @moduledoc """
  Photo blacklist management using perceptual hashing (dhash).

  Provides functionality to maintain a blacklist of banned images using
  difference hashing (dhash) for perceptual similarity matching.
  """

  import Ecto.Query

  alias Animina.ActivityLog
  alias Animina.Photos
  alias Animina.Photos.Photo
  alias Animina.Photos.PhotoBlacklist
  alias Animina.Repo
  alias Animina.Repo.Paginator

  @doc """
  Computes the dhash (perceptual hash) for an image.
  Returns an 8-byte binary representing the 64-bit hash.
  """
  def compute_dhash(image_path) do
    with {:ok, image} <- Image.open(image_path) do
      Image.dhash(image)
    end
  end

  @doc """
  Returns the directory for blacklist thumbnails.
  """
  def blacklist_dir do
    Path.join(Photos.upload_dir(), "blacklist")
  end

  @doc """
  Adds a dhash to the blacklist, copying the thumbnail for reference.
  """
  def add_to_blacklist(dhash, reason, added_by, source_photo \\ nil) do
    thumbnail_path = copy_thumbnail_to_blacklist(source_photo)

    attrs = %{
      dhash: dhash,
      reason: reason,
      thumbnail_path: thumbnail_path,
      added_by_id: added_by && added_by.id,
      source_photo_id: source_photo && source_photo.id,
      source_user_id: source_photo && source_photo.owner_id
    }

    result =
      %PhotoBlacklist{}
      |> PhotoBlacklist.create_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, entry} ->
        ActivityLog.log("admin", "blacklist_entry_added", "Photo added to blacklist: #{reason}",
          actor_id: added_by && added_by.id,
          metadata: %{"reason" => reason, "blacklist_id" => entry.id}
        )

        {:ok, entry}

      error ->
        error
    end
  end

  defp copy_thumbnail_to_blacklist(nil), do: nil

  defp copy_thumbnail_to_blacklist(%Photo{} = photo) do
    source = Photos.FileManagement.processed_path(photo, :thumbnail)

    if File.exists?(source) do
      blacklist_dir = blacklist_dir()
      File.mkdir_p!(blacklist_dir)

      filename = "#{Ecto.UUID.generate()}_thumb.webp"
      dest = Path.join(blacklist_dir, filename)

      case File.cp(source, dest) do
        :ok -> dest
        {:error, _} -> nil
      end
    else
      nil
    end
  end

  @doc """
  Removes an entry from the blacklist and deletes its thumbnail.
  """
  def remove_from_blacklist(%PhotoBlacklist{} = entry) do
    if entry.thumbnail_path && File.exists?(entry.thumbnail_path) do
      File.rm(entry.thumbnail_path)
    end

    result = Repo.delete(entry)

    case result do
      {:ok, _} ->
        ActivityLog.log("admin", "blacklist_entry_removed", "Photo removed from blacklist",
          metadata: %{"blacklist_id" => entry.id}
        )

      _ ->
        :ok
    end

    result
  end

  @doc """
  Checks if a dhash matches any blacklist entry within the hamming distance threshold.
  Returns the matching entry or nil.

  Uses a single PostgreSQL query with the database-side `hamming_distance` function
  for efficient lookup. This scales to 100k+ entries with minimal overhead.
  """
  def check_blacklist(dhash, threshold \\ nil) do
    threshold = threshold || Photos.blacklist_hamming_threshold()

    query =
      from(b in PhotoBlacklist,
        where: fragment("hamming_distance(?, ?)", b.dhash, ^dhash) <= ^threshold,
        limit: 1
      )

    Repo.one(query)
  end

  @doc """
  Computes the hamming distance between two binary hashes.
  """
  def hamming_distance(hash1, hash2) when byte_size(hash1) == byte_size(hash2) do
    hash1
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(hash2))
    |> Enum.reduce(0, fn {a, b}, acc ->
      acc + count_bits(Bitwise.bxor(a, b))
    end)
  end

  def hamming_distance(_, _), do: 64

  defp count_bits(0), do: 0
  defp count_bits(n), do: Bitwise.band(n, 1) + count_bits(Bitwise.bsr(n, 1))

  @doc """
  Gets a blacklist entry by exact dhash match.
  """
  def get_blacklist_entry_by_dhash(dhash) do
    PhotoBlacklist
    |> where([b], b.dhash == ^dhash)
    |> Repo.one()
  end

  @doc """
  Gets a blacklist entry by ID.
  """
  def get_blacklist_entry(id) do
    Repo.get(PhotoBlacklist, id)
  end

  @doc """
  Lists all blacklist entries.
  """
  def list_blacklist_entries do
    PhotoBlacklist
    |> order_by([b], desc: b.inserted_at)
    |> preload([:added_by, :source_photo, :source_user])
    |> Repo.all()
  end

  @doc """
  Lists blacklist entries with pagination.

  ## Options

    * `:page` - page number (default: 1)
    * `:per_page` - items per page (default: 50)
    * `:viewer_id` - if provided, excludes entries related to the viewer's own photos
      unless they are the only admin in the system
  """
  def list_blacklist_entries_paginated(opts \\ []) do
    viewer_id = Keyword.get(opts, :viewer_id)

    PhotoBlacklist
    |> maybe_exclude_own_blacklist_entries(viewer_id)
    |> order_by([b], desc: b.inserted_at)
    |> Paginator.paginate(
      page: opts[:page],
      per_page: opts[:per_page],
      max_per_page: 250,
      preload: [:added_by, :source_photo, :source_user]
    )
  end

  defp maybe_exclude_own_blacklist_entries(query, nil), do: query

  defp maybe_exclude_own_blacklist_entries(query, viewer_id) do
    if Animina.Accounts.count_users_with_role("admin") > 1 do
      where(query, [b], b.source_user_id != ^viewer_id or is_nil(b.source_user_id))
    else
      query
    end
  end
end
