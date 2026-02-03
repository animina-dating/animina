defmodule Animina.Utils.Timezone do
  @moduledoc """
  Shared timezone utilities, primarily for Europe/Berlin conversions.
  """

  @doc """
  Returns the UTC datetime range for "today" in Europe/Berlin timezone.

  Returns `{start_utc, end_utc}` where:
  - `start_utc` is midnight Berlin time converted to UTC
  - `end_utc` is midnight tomorrow Berlin time converted to UTC

  This is useful for queries that need to filter by "today" in Berlin time
  regardless of the server's timezone.
  """
  def berlin_today_utc_range do
    now_berlin =
      DateTime.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    today_date = DateTime.to_date(now_berlin)
    tomorrow_date = Date.add(today_date, 1)

    start_utc = midnight_berlin_to_utc(today_date)
    end_utc = midnight_berlin_to_utc(tomorrow_date)

    {start_utc, end_utc}
  end

  defp midnight_berlin_to_utc(date) do
    {:ok, naive} = NaiveDateTime.new(date, ~T[00:00:00])
    {:ok, dt} = DateTime.from_naive(naive, "Europe/Berlin", Tz.TimeZoneDatabase)
    DateTime.shift_zone!(dt, "Etc/UTC", Tz.TimeZoneDatabase)
  end

  @doc """
  Returns the current UTC offset in seconds for Europe/Berlin timezone.

  This accounts for both the standard offset and any daylight saving time offset.

  ## Examples

      # During winter (CET, UTC+1):
      iex> berlin_utc_offset_seconds()
      3600

      # During summer (CEST, UTC+2):
      iex> berlin_utc_offset_seconds()
      7200
  """
  def berlin_utc_offset_seconds do
    now_berlin =
      DateTime.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    now_berlin.utc_offset + now_berlin.std_offset
  end
end
