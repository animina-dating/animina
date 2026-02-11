defmodule Animina.DiscoveryFixtures do
  @moduledoc """
  Test helpers for creating discovery entities.
  """

  alias Animina.Discovery.Schemas.SpotlightEntry
  alias Animina.Repo
  alias Animina.TimeMachine

  @doc """
  Creates a spotlight entry so that `viewer` can see `shown_user`'s moodboard today.
  Also creates the reverse entry for bidirectional access.
  """
  def spotlight_entry_fixture(viewer, shown_user, opts \\ []) do
    today = berlin_today()
    is_wildcard = Keyword.get(opts, :is_wildcard, false)
    now = TimeMachine.utc_now() |> DateTime.truncate(:second)

    Repo.insert_all(
      SpotlightEntry,
      [
        %{
          id: Ecto.UUID.generate(),
          user_id: viewer.id,
          shown_user_id: shown_user.id,
          shown_on: today,
          is_wildcard: is_wildcard,
          cycle_number: 0,
          inserted_at: now,
          updated_at: now
        },
        %{
          id: Ecto.UUID.generate(),
          user_id: shown_user.id,
          shown_user_id: viewer.id,
          shown_on: today,
          is_wildcard: is_wildcard,
          cycle_number: 0,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing
    )
  end

  defp berlin_today do
    TimeMachine.utc_now()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> DateTime.to_date()
  end
end
