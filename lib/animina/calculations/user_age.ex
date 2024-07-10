defmodule Animina.Calculations.UserAge do
  @moduledoc """
  This is a module for calculating the current age of a user.
  """

  use Ash.Resource.Calculation

  def calculate(records, opts, _) do
    Enum.map(records, fn record -> calculate_age(Map.get(record, opts[:field])) end)
  end

  defp calculate_age(birthdate) do
    today = Date.utc_today()
    days = Date.diff(today, birthdate)
    years = days / 365.25
    floor(years)
  end
end
