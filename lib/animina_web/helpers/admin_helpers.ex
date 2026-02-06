defmodule AniminaWeb.Helpers.AdminHelpers do
  @moduledoc """
  Shared helper functions for admin LiveViews.

  Provides common utilities for pagination, formatting, and parsing
  that are used across multiple admin pages.
  """

  @doc """
  Parses a string value as a positive integer (> 0), returning a default if parsing fails.

  Used for pagination where page numbers must be positive.

  ## Examples

      iex> parse_int("10", 1)
      10

      iex> parse_int(nil, 1)
      1

      iex> parse_int("0", 1)
      1

      iex> parse_int("invalid", 5)
      5
  """
  def parse_int(nil, default), do: default

  def parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  def parse_int(val, _default) when is_integer(val) and val > 0, do: val
  def parse_int(_, default), do: default

  @doc """
  Parses a string value as a non-negative integer (>= 0), returning a default if parsing fails.

  Used for values like delay_ms where 0 is a valid value.

  ## Examples

      iex> parse_non_negative_int("10", 0)
      10

      iex> parse_non_negative_int("0", 5)
      0

      iex> parse_non_negative_int("-5", 0)
      0
  """
  def parse_non_negative_int(nil, default), do: default

  def parse_non_negative_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n >= 0 -> n
      _ -> default
    end
  end

  def parse_non_negative_int(val, _default) when is_integer(val) and val >= 0, do: val
  def parse_non_negative_int(_, default), do: default

  @doc """
  Converts a snake_case key to a human-readable format.

  ## Examples

      iex> humanize_key(:nsfw_score)
      "Nsfw score"

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
  def format_value(value), do: to_string(value)

  @doc """
  Formats a datetime for display.

  ## Examples

      iex> format_datetime(~U[2024-01-15 10:30:00Z])
      "2024-01-15 10:30"

      iex> format_datetime(nil)
      ""
  """
  def format_datetime(nil), do: ""

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

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

  @doc """
  Parses a string value as an integer (including negative values), returning a default if parsing fails.

  Unlike `parse_int/2` and `parse_non_negative_int/2`, this allows negative values.
  Used for settings like discovery score penalties.

  ## Examples

      iex> parse_integer("10", 0)
      10

      iex> parse_integer("-15", 0)
      -15

      iex> parse_integer("invalid", 5)
      5
  """
  def parse_integer(nil, default), do: default

  def parse_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  def parse_integer(val, _default) when is_integer(val), do: val
  def parse_integer(_, default), do: default
end
