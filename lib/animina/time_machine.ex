defmodule Animina.TimeMachine do
  @moduledoc """
  Dev-only time travel for testing time-sensitive features.

  In dev: shifts the app's perception of "now" by a configurable offset
  stored in `:persistent_term`. Mutation functions (`add_hours/1`, `add_days/1`,
  `reset/0`) adjust the offset. The offset resets to 0 on app restart.

  In prod/test: all functions compile to direct passthroughs with zero overhead.
  Mutation functions are no-ops.
  """

  @dev Application.compile_env(:animina, :dev_routes)

  if @dev do
    @key :time_machine_offset_seconds

    @doc "Returns DateTime.utc_now() shifted by the current offset."
    def utc_now do
      DateTime.utc_now() |> DateTime.add(offset_seconds(), :second)
    end

    @doc "Returns DateTime.utc_now() shifted and truncated to the given precision."
    def utc_now(precision) do
      utc_now() |> DateTime.truncate(precision)
    end

    @doc "Returns Date.utc_today() shifted by the current offset."
    def utc_today do
      utc_now() |> DateTime.to_date()
    end

    @doc "Adds hours to the current offset."
    def add_hours(n) when is_integer(n) do
      new_offset = offset_seconds() + n * 3600
      :persistent_term.put(@key, new_offset)
      :ok
    end

    @doc "Adds days to the current offset."
    def add_days(n) when is_integer(n) do
      new_offset = offset_seconds() + n * 86_400
      :persistent_term.put(@key, new_offset)
      :ok
    end

    @doc "Resets the offset to zero."
    def reset do
      :persistent_term.put(@key, 0)
      :ok
    end

    @doc """
    Returns a human-readable offset string (e.g. "+2d 3h") or nil when offset is 0.
    """
    def format_offset do
      secs = offset_seconds()
      if secs == 0, do: nil, else: format_seconds(secs)
    end

    @doc "Returns the virtual now as a formatted string for display."
    def virtual_now do
      Calendar.strftime(utc_now(), "%b %d, %Y %H:%M UTC")
    end

    defp offset_seconds do
      :persistent_term.get(@key)
    rescue
      ArgumentError -> 0
    end

    defp format_seconds(total) do
      sign = if total >= 0, do: "+", else: "-"
      abs_secs = abs(total)
      days = div(abs_secs, 86_400)
      hours = div(rem(abs_secs, 86_400), 3600)
      minutes = div(rem(abs_secs, 3600), 60)

      parts =
        []
        |> then(fn acc -> if days > 0, do: acc ++ ["#{days}d"], else: acc end)
        |> then(fn acc -> if hours > 0, do: acc ++ ["#{hours}h"], else: acc end)
        |> then(fn acc -> if minutes > 0, do: acc ++ ["#{minutes}m"], else: acc end)

      case parts do
        [] -> "#{sign}0h"
        _ -> sign <> Enum.join(parts, " ")
      end
    end
  else
    def utc_now, do: DateTime.utc_now()
    def utc_now(precision), do: DateTime.utc_now(precision)
    def utc_today, do: Date.utc_today()

    def add_hours(_n), do: :ok
    def add_days(_n), do: :ok
    def reset, do: :ok

    def format_offset, do: nil

    def virtual_now do
      Calendar.strftime(DateTime.utc_now(), "%b %d, %Y %H:%M UTC")
    end
  end
end
