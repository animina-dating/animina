defmodule Animina.Discovery.CandidateFilter do
  @moduledoc """
  Orchestrates candidate filtering using the configured filter module.

  This module delegates to the filter implementation selected via feature flags,
  allowing runtime switching between different filter strategies.
  """

  import Ecto.Query

  alias Animina.Accounts.User
  alias Animina.Discovery.Settings
  alias Animina.Repo
  alias Animina.Traits.Matching

  @doc """
  Returns a base query for candidate users.
  """
  def base_query do
    from(u in User, as: :user)
  end

  @doc """
  Filters candidates using the configured filter module.

  Options:
  - `:list_type` - The type of list being generated ("combined", "safe", "attracted")
  """
  def filter_candidates(query, viewer, opts \\ []) do
    filter_module = Settings.filter_module()
    filter_module.filter_candidates(query, viewer, opts)
  end

  @doc """
  Returns filtered candidates as a list, preloading necessary associations.
  """
  def get_filtered_candidates(viewer, opts \\ []) do
    base_query()
    |> filter_candidates(viewer, opts)
    |> preload([:locations])
    |> Repo.all()
  end

  @doc """
  Filters candidates for the Combined list (includes soft-red, excludes hard-red).
  """
  def filter_for_combined(viewer) do
    get_filtered_candidates(viewer, list_type: "combined")
    |> filter_by_hard_red(viewer)
  end

  @doc """
  Filters candidates for the Safe list (no red flags at all).
  """
  def filter_for_safe(viewer) do
    get_filtered_candidates(viewer, list_type: "safe")
    |> filter_by_any_red(viewer)
  end

  @doc """
  Filters candidates for the Attracted list (excludes hard-red).
  """
  def filter_for_attracted(viewer) do
    get_filtered_candidates(viewer, list_type: "attracted")
    |> filter_by_hard_red(viewer)
  end

  # --- Red Flag Filtering ---

  # These filters need to be done in-memory because they require
  # computing flag overlap which involves complex trait matching

  defp filter_by_hard_red(candidates, viewer) do
    Enum.reject(candidates, fn candidate ->
      overlap = Matching.compute_flag_overlap(viewer, candidate)
      overlap.red_white_hard != []
    end)
  end

  defp filter_by_any_red(candidates, viewer) do
    Enum.reject(candidates, fn candidate ->
      overlap = Matching.compute_flag_overlap(viewer, candidate)
      overlap.red_white != []
    end)
  end
end
