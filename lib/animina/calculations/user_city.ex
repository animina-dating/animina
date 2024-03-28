defmodule Animina.Calculations.UserCity do
  @moduledoc """
  This is a module for getting a user's city.
  """

  alias Animina.GeoData
  use Ash.Calculation

  def calculate(records, opts, _) do
    Enum.map(records, fn record -> get_city(Map.get(record, opts[:field])) end)
  end

  defp get_city(zip_code) do
    GeoData.City.by_zip_code!(zip_code)
  end
end
