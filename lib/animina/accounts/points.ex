defmodule Animina.Accounts.Points do
  @moduledoc """
  This is the module to handle the credit points
  """

  def humanized_points(nil) do
    "0"
  end

  def humanized_points(points) when is_integer(points) and points < 1_000 do
    Integer.to_string(points)
  end

  def humanized_points(points) when is_integer(points) and points < 1_000_000 do
    Integer.to_string(div(points, 1_000)) <> "\u{00a0}k"
  end

  def humanized_points(points) when is_integer(points) do
    Integer.to_string(div(points, 1_000_000)) <> "\u{00a0}M"
  end

  def has_daily_bonus_for_the_past_ten_days(credits, current_day) do
    past_ten_days = array_with_previous_ten_days(current_day)
    credits_map = Enum.group_by(credits, &format_date(&1.created_at))

    Enum.all?(past_ten_days, fn day ->
      Map.has_key?(credits_map, day)
    end)
  end

  defp array_with_previous_ten_days(current_day) do
    Enum.map(0..10, fn day ->
      Timex.shift(current_day, days: -day)
      |> format_date()
    end)
  end

  defp format_date(date) do
    {:ok, date} = Timex.format(date, "{YYYY}-{0M}-{0D}")
    date
  end

  def format_time(time) do
    NaiveDateTime.from_erl!({{2000, 1, 1}, Time.to_erl(time)}) |> Timex.format!("{h12}:{0m} {am}")
  end
end
