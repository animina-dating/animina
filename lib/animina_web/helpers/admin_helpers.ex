defmodule AniminaWeb.Helpers.AdminHelpers do
  @moduledoc """
  Shared helper functions for admin LiveViews.

  Provides common utilities for pagination, formatting, and parsing
  that are used across multiple admin pages.
  """

  @doc """
  Parses a string or integer value, returning a default if parsing fails.

  Supports a `:min` option to enforce a minimum value.

  ## Examples

      iex> parse_int("10", 1)
      10

      iex> parse_int(nil, 1)
      1

      iex> parse_int("0", 1)
      1

      iex> parse_int("invalid", 5)
      5

      iex> parse_int("0", 0, min: 0)
      0

      iex> parse_int("-5", 0, min: 0)
      0

      iex> parse_int("-15", 0, min: nil)
      -15
  """
  def parse_int(val, default, opts \\ [])

  def parse_int(nil, default, _opts), do: default

  def parse_int(val, default, opts) when is_binary(val) do
    min = Keyword.get(opts, :min, 1)

    case Integer.parse(val) do
      {n, _} -> if is_nil(min) or n >= min, do: n, else: default
      :error -> default
    end
  end

  def parse_int(val, default, opts) when is_integer(val) do
    min = Keyword.get(opts, :min, 1)
    if is_nil(min) or val >= min, do: val, else: default
  end

  def parse_int(_, default, _opts), do: default

  @doc """
  Parses a non-negative integer (>= 0). Shorthand for `parse_int(val, default, min: 0)`.
  """
  def parse_non_negative_int(val, default), do: parse_int(val, default, min: 0)

  @doc """
  Parses any integer including negative. Shorthand for `parse_int(val, default, min: nil)`.
  """
  def parse_integer(val, default), do: parse_int(val, default, min: nil)

  @doc """
  Converts a snake_case key to a human-readable format.

  ## Examples

      iex> humanize_key("confidence_level")
      "Confidence level"
  """
  def humanize_key(key) when is_atom(key), do: humanize_key(Atom.to_string(key))

  def humanize_key(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @doc """
  Formats a value for display in admin interfaces.

  Handles floats (rounds to 3 decimals), booleans, nil, and other values.

  ## Examples

      iex> format_value(0.123456)
      "0.123"

      iex> format_value(true)
      "true"

      iex> format_value(nil)
      "-"
  """
  def format_value(value) when is_float(value), do: Float.round(value, 3) |> to_string()
  def format_value(value) when is_boolean(value), do: to_string(value)
  def format_value(nil), do: "-"
  def format_value(value) when is_map(value), do: Jason.encode!(value)
  def format_value(value) when is_list(value), do: Jason.encode!(value)
  def format_value(value), do: to_string(value)

  @doc """
  Formats a datetime for display in Europe/Berlin timezone.

  Shows "HH:MM:SS" for today's entries, full "YYYY-MM-DD HH:MM:SS" otherwise.

  ## Examples

      iex> format_datetime(nil)
      ""
  """
  def format_datetime(nil), do: ""

  def format_datetime(datetime) do
    berlin_dt = DateTime.shift_zone!(datetime, "Europe/Berlin", Tz.TimeZoneDatabase)
    berlin_date = DateTime.to_date(berlin_dt)

    now_berlin =
      Animina.TimeMachine.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    today = DateTime.to_date(now_berlin)

    if berlin_date == today do
      Calendar.strftime(berlin_dt, "%H:%M:%S")
    else
      Calendar.strftime(berlin_dt, "%Y-%m-%d %H:%M:%S")
    end
  end

  @doc """
  Returns the DaisyUI badge class for an email log status.

  ## Examples

      iex> email_status_badge_class("sent")
      "badge-success"

      iex> email_status_badge_class("bounced")
      "badge-warning"

      iex> email_status_badge_class("error")
      "badge-error"
  """
  def email_status_badge_class("sent"), do: "badge-success"
  def email_status_badge_class("bounced"), do: "badge-warning"
  def email_status_badge_class(_), do: "badge-error"

  @doc """
  Parses a days parameter from URL params.

  Accepts "7", "30", or "90", defaulting to 30.
  """
  def parse_days("7"), do: 7
  def parse_days("90"), do: 90
  def parse_days(_), do: 30

  @doc """
  Formats a datetime with seconds for detailed views.

  ## Examples

      iex> format_datetime_full(~U[2024-01-15 10:30:45Z])
      "2024-01-15 10:30:45"
  """
  def format_datetime_full(nil), do: ""

  def format_datetime_full(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
