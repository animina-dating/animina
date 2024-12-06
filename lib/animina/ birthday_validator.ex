defmodule Animina.BirthdayValidator do
  @moduledoc """
  A module to validate a birthday in the format dd.mm.yy.
  """

  @doc """
  Validates a birthday string in the format dd.mm.yy.

  ## Examples

      iex> BirthdayValidator.validate_birthday("15.08.95")
      {:ok, ~D[1995-08-15]}

      iex> BirthdayValidator.validate_birthday("32.01.21")
      {:error, "Invalid day for the given month."}

      iex> BirthdayValidator.validate_birthday("29.02.21")
      {:error, "Invalid day for the given month."}

      iex> BirthdayValidator.validate_birthday("15.08.30")
      {:error, "Birthday cannot be in the future."}

      iex> BirthdayValidator.validate_birthday("15.08.2005")
      {:ok, ~D[2005-08-15]}

      iex> BirthdayValidator.validate_birthday("15.08.2010")
      {:error, "Birthday must be more than 18 years ago."}
  """
  def validate_birthday(birthday) do
    with {:ok, date_parts} <- parse_birthday(birthday),
         {:ok, date} <- validate_date(date_parts),
         :ok <- check_not_future(date),
         :ok <- check_age(date) do
      {:ok, date}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_birthday(birthday) do
    case String.split(birthday, ".") do
      [day, month, year] ->
        case {Integer.parse(day), Integer.parse(month), Integer.parse(year)} do
          {{day_int, ""}, {month_int, ""}, {year_int, ""}} ->
            {:ok, {day_int, month_int, adjust_year(year_int, String.length(year))}}

          _ ->
            {:error, "Invalid format. Must be dd.mm.yy or dd.mm.yyyy."}
        end

      _ ->
        {:error, "Invalid format. Must be dd.mm.yy or dd.mm.yyyy."}
    end
  end

  defp adjust_year(year_int, 1), do: 2000 + year_int

  defp adjust_year(year_int, 2) do
    current_year = Date.utc_today().year
    current_two_digits = rem(current_year, 100)

    if year_int > current_two_digits do
      1900 + year_int
    else
      2000 + year_int
    end
  end

  defp adjust_year(year_int, 4), do: year_int

  defp validate_date({day, month, year}) do
    padded_day = String.pad_leading(Integer.to_string(day), 2, "0")
    padded_month = String.pad_leading(Integer.to_string(month), 2, "0")

    date_str = "#{year}-#{padded_month}-#{padded_day}"

    case Date.from_iso8601(date_str) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "Invalid day for the given month."}
    end
  end

  defp check_not_future(date) do
    if Date.compare(date, Date.utc_today()) != :gt do
      :ok
    else
      {:error, "Birthday cannot be in the future."}
    end
  end

  defp check_age(date) do
    # Calculate the threshold date (18 years ago)
    # Approximate 18 years
    age_threshold = Date.utc_today() |> Date.add(-18 * 365)

    if Date.compare(date, age_threshold) != :gt do
      :ok
    else
      {:error, "Birthday must be more than 18 years ago."}
    end
  end
end
