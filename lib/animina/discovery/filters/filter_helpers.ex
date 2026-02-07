defmodule Animina.Discovery.Filters.FilterHelpers do
  @moduledoc """
  Shared helper functions for discovery filter strategies.
  """

  alias Animina.Accounts
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

  defdelegate compute_age(birthday), to: Accounts

  defp primary_zip_code(%{locations: [%{position: 1, zip_code: zip} | _]}), do: zip

  defp primary_zip_code(%{locations: locations}) when is_list(locations) do
    Enum.find_value(locations, fn loc ->
      if loc.position == 1, do: loc.zip_code
    end)
  end

  defp primary_zip_code(_), do: nil
end
