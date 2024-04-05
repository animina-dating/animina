defmodule AniminaWeb.PotentialPartner do
  @moduledoc """
  Functions for querying potential partners.
  """

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.GeoData
  alias Animina.GeoData.City
  alias Animina.Traits
  alias Animina.Traits.UserFlags

  require Ash.Query
  require Ash.Sort

  @doc """
  Gets potential partners for the given user.

  ## Options

    * `"limit"` -
      The number of potential partners to return from the query. Defaults to `10`

    * `"strict_red_flags"` -
      Whether to filter the potential partners by eliminating those that have red flags defined by the user. Defaults to `false`

  """
  def potential_partners(user, options \\ []) do
    limit = Keyword.get(options, :limit, 10)
    strict_red_flags = Keyword.get(options, :strict_red_flags, false)

    User
    |> Ash.Query.for_read(:read)
    |> Ash.Query.sort(Ash.Sort.expr_sort(fragment("RANDOM()")))
    |> partner_age_query(user)
    |> partner_height_query(user)
    |> partner_gender_query(user)
    |> partner_geo_query(user)
    |> partner_green_flags_query(user)
    |> partner_red_flags_query(user, strict_red_flags)
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
    |> Ash.Query.filter(zip_code: [in: nearby_zip_codes])
  end

  defp partner_green_flags_query(query, user) do
    white_flags =
      get_user_flags(user.id, :white)
      |> Enum.map(fn flag -> flag.flag_id end)

    query
    |> Ash.Query.filter(flags.color == :green and flags.flag_id in ^white_flags)
  end

  defp partner_red_flags_query(query, user, strict_red_flags) when strict_red_flags == true do
    red_flags =
      get_user_flags(user.id, :red)
      |> Enum.map(fn flag -> flag.flag_id end)

    query
    |> Ash.Query.filter(flags.color == :white and flags.flag_id not in ^red_flags)
  end

  defp partner_red_flags_query(query, _user, _strict_red_flags) do
    query
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

  def get_user_flags(user_id, color) do
    UserFlags
    |> Ash.Query.for_read(:by_user_id, %{id: user_id, color: color})
    |> Traits.read!()
  end
end
