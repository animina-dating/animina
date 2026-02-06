defmodule Animina.Discovery.Filters.FilterHelpers do
  @moduledoc """
  Shared helper functions for discovery filter strategies.
  """

  alias Animina.GeoData

  @doc """
  Extracts the viewer's primary location coordinates (lat/lon).

  Returns `{:ok, lat, lon}` if found, `:error` otherwise.
  """
  def get_viewer_coordinates(viewer) do
    with zip_code when not is_nil(zip_code) <- primary_zip_code(viewer),
         %{lat: lat, lon: lon} when not is_nil(lat) and not is_nil(lon) <-
           GeoData.get_city_by_zip_code(zip_code) do
      {:ok, lat, lon}
    else
      _ -> :error
    end
  end

  @doc """
  Computes a user's age in years from their birthday.
  """
  def compute_age(nil), do: nil

  def compute_age(birthday) do
    today = Date.utc_today()
    age = today.year - birthday.year

    if {today.month, today.day} < {birthday.month, birthday.day},
      do: age - 1,
      else: age
  end

  defp primary_zip_code(%{locations: [%{position: 1, zip_code: zip} | _]}), do: zip

  defp primary_zip_code(%{locations: locations}) when is_list(locations) do
    Enum.find_value(locations, fn loc ->
      if loc.position == 1, do: loc.zip_code
    end)
  end

  defp primary_zip_code(_), do: nil
end
