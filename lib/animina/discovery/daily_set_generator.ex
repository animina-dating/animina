defmodule Animina.Discovery.DailySetGenerator do
  @moduledoc """
  Generates and persists a daily discovery set for a user.

  Each user gets a fixed set of suggestions per day (Berlin date).
  Once generated, the set is stored in `daily_discovery_sets` and returned
  on subsequent requests for the same day.
  """

  import Ecto.Query

  alias Animina.Discovery.Schemas.DailyDiscoverySet
  alias Animina.Discovery.{Settings, SuggestionGenerator}
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Traits.Matching

  @doc """
  Returns the daily discovery set for the viewer.

  If a set already exists for today (Berlin date), it returns those candidates.
  Otherwise, it generates a new set from the suggestion engine and persists it.

  Returns a list of suggestion maps (same shape as SuggestionGenerator output).
  """
  def get_or_generate(viewer) do
    today = berlin_today()

    case get_existing_set(viewer.id, today) do
      [] -> generate_and_store(viewer, today)
      existing -> hydrate_existing(existing, viewer)
    end
  end

  defp berlin_today do
    TimeMachine.utc_now()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> DateTime.to_date()
  end

  defp get_existing_set(user_id, date) do
    DailyDiscoverySet
    |> where([d], d.user_id == ^user_id and d.set_date == ^date)
    |> order_by([d], asc: d.position)
    |> Repo.all()
  end

  defp generate_and_store(viewer, today) do
    set_size = Settings.daily_set_size()

    # Generate scored suggestions
    combined = SuggestionGenerator.generate_combined(viewer)
    scored = Enum.take(combined, set_size)

    # Generate wildcards (excluding scored candidates)
    scored_ids = Enum.map(scored, & &1.user.id)
    wildcards = SuggestionGenerator.generate_wildcards(viewer, scored_ids)

    all_suggestions = scored ++ wildcards

    # Record views for cooldown tracking
    SuggestionGenerator.record_views(viewer, all_suggestions)

    # Persist the set
    all_suggestions
    |> Enum.with_index()
    |> Enum.each(fn {suggestion, idx} ->
      %DailyDiscoverySet{}
      |> DailyDiscoverySet.changeset(%{
        user_id: viewer.id,
        candidate_id: suggestion.user.id,
        set_date: today,
        is_wildcard: suggestion.list_type == "wildcard",
        position: idx
      })
      |> Repo.insert()
    end)

    all_suggestions
  end

  defp hydrate_existing(set_entries, viewer) do
    candidate_ids = Enum.map(set_entries, & &1.candidate_id)

    users =
      Animina.Accounts.User
      |> where([u], u.id in ^candidate_ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    viewer = Repo.preload(viewer, [:locations])

    Enum.map(set_entries, fn entry ->
      candidate = Map.get(users, entry.candidate_id)

      if candidate do
        hydrate_candidate(entry, candidate, viewer)
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp hydrate_candidate(%{is_wildcard: true}, candidate, _viewer) do
    %{
      user: candidate,
      score: 0,
      overlap: %{red_white_soft: [], green_white: [], white_white: []},
      list_type: "wildcard",
      has_soft_red: false,
      soft_red_count: 0,
      green_count: 0,
      white_white_count: 0,
      white_white_flag_ids: [],
      published_white_flags: []
    }
  end

  defp hydrate_candidate(_entry, candidate, viewer) do
    overlap = Matching.compute_flag_overlap(viewer, candidate)

    %{
      user: candidate,
      score: 0,
      overlap: overlap,
      list_type: "combined",
      has_soft_red: overlap.red_white_soft != [],
      soft_red_count: length(overlap.red_white_soft),
      green_count: length(overlap.green_white),
      white_white_count: length(overlap.white_white),
      white_white_flag_ids: overlap.white_white,
      published_white_flags: []
    }
  end
end
