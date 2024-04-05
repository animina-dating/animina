defmodule AniminaWeb.PotentialPartner do
  @moduledoc """
  Functions for querying potential partners.
  """

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.GeoData
  alias Animina.GeoData.City

  require Ash.Query
  require Ash.Sort

  @doc """
  Gets potential partners for the given user.
  """
  def potential_partners(user, limit \\ 10) do
    User
    |> Ash.Query.for_read(:read)
    |> Ash.Query.sort(Ash.Sort.expr_sort(fragment("RANDOM()")))
    |> partner_age_query(user)
    |> partner_height_query(user)
    |> partner_gender_query(user)
    |> partner_geo_query(user)
    |> Ash.Query.limit(limit)
    |> Accounts.read!()
  end

  defp partner_height_query(query, user) do
    query
    |> Ash.Query.filter(
      or: [
        height: [less_than_or_equal: user.maximum_partner_height],
        height: [greater_than_or_equal: user.minimum_partner_height]
      ]
    )
  end

  # We use a fragment query to calculate the age of the user as
  # ash does not support using module calculations defined with calculate/3 in filter queries
  defp partner_age_query(query, user) do
    query
    |> Ash.Query.filter(
      fragment("date_part('year', age(current_date, ?))", birthday) <= ^user.maximum_partner_age and
        fragment("date_part('year', age(current_date, ?))", birthday) >= ^user.minimum_partner_age
    )
  end

  defp partner_gender_query(query, user) do
    query
    |> Ash.Query.filter(gender: [eq: user.partner_gender])
  end

  defp partner_geo_query(query, user) do
    nearby_zip_codes =
      get_nearby_cities(user.zip_code, user.search_range)
      |> Enum.map(fn city -> city.zip_code end)

    query
    |> Ash.Query.filter(
      or: [
        zip_code: [in: nearby_zip_codes]
      ]
    )
  end

  # We use the haversine formula to get locations
  # near the current city in the search range radius
  defp get_nearby_cities(zip_code, search_range) do
    current_city = City.by_zip_code!(zip_code)

    City
    |> Ash.Query.filter(
      fragment(
        "acos(sin(radians(?)) * sin(radians(lat)) + cos(radians(?)) * cos(radians(lat)) * cos(radians(?) - radians(lon))) * 6731 <= ?",
        ^current_city.lat,
        ^current_city.lat,
        ^current_city.lon,
        ^search_range
      )
    )
    |> GeoData.read!()
  end
end
