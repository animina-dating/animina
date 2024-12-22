defmodule AniminaWeb.PotentialPartner do
  @moduledoc """
  Functions for querying potential partners.
  """

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.BirthdayValidator
  alias Animina.GeoData.City
  alias Phoenix.PubSub
  # alias Animina.Traits.UserFlags

  require Ash.Query
  require Ash.Sort

  @doc """
  Gets potential partners for the given user.

  ## Options

    * `"limit"` -
      The number of potential partners to return from the query. Defaults to `10`

    * `"strict_red_flags"` -
      Whether to filter the potential partners by eliminating those that have red flags defined by the user. Defaults to `false`


      * `remove_bookmarked_potential_users` -
      Whether to remove the potential partners that have been bookmarked by the user. Defaults to `true`

  """
  def potential_partners(user, options \\ []) do
    limit = Keyword.get(options, :limit, 10)
    # strict_red_flags = Keyword.get(options, :strict_red_flags, false)
    # remove_bookmarked = Keyword.get(options, :remove_bookmarked_potential_users, true)

    User
    |> Ash.Query.for_read(:read)
    |> Ash.Query.sort(Ash.Sort.expr_sort(fragment("RANDOM()")))
    |> partner_gender_query(user)
    # |> partner_age_query(user)
    # |> partner_height_query(user)
    # |> partner_geo_query(user)
    # |> partner_green_flags_query(user)
    # |> partner_red_flags_query(user, strict_red_flags)
    |> partner_not_self_query(user)
    |> partner_completed_registration_query(user)
    |> partner_not_under_investigation_query(user)
    |> partner_not_banned_query(user)
    |> partner_not_archived_query(user)
    |> partner_not_hibernate_query(user)
    |> partner_not_incognito_query(user)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end

  @doc """
  We use this to fetch potential partners for the user during registration.
  """

  def potential_partners_on_registration(user) do
    users =
      User
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(Ash.Sort.expr_sort(fragment("RANDOM()")))
      |> registration_partner_gender_query(user)
      |> registration_partner_height_query(user)
      |> registration_partner_age_query(user)
      |> registration_partner_geo_query(user)
      |> partner_completed_registration_query(user)
      |> partner_not_under_investigation_query(user)
      |> partner_not_banned_query(user)
      |> partner_not_archived_query(user)
      |> partner_not_hibernate_query(user)
      |> partner_not_incognito_query(user)
      |> Ash.read!()

    PubSub.broadcast(
      Animina.PubSub,
      "potential_partners_on_registration",
      {:potential_partners, users}
    )
  end

  defp partner_completed_registration_query(query, _user) do
    query
    |> Ash.Query.filter(not is_nil(registration_completed_at))
  end

  def partner_not_under_investigation_query(query, _user) do
    query
    |> Ash.Query.filter(state: [not_eq: :under_investigation])
  end

  def partner_not_banned_query(query, _user) do
    query
    |> Ash.Query.filter(state: [not_eq: :banned])
  end

  def partner_not_archived_query(query, _user) do
    query
    |> Ash.Query.filter(state: [not_eq: :archived])
  end

  def partner_not_hibernate_query(query, _user) do
    query
    |> Ash.Query.filter(state: [not_eq: :hibernate])
  end

  def partner_not_incognito_query(query, _user) do
    query
    |> Ash.Query.filter(state: [not_eq: :incognito])
  end

  def partner_not_self_query(query, user) do
    query
    |> Ash.Query.filter(id: [not_eq: user.id])
  end

  def partner_bookmarked_query(query, _user, false) do
    query
  end

  def partner_bookmarked_query(query, user, true) do
    bookmarked_users =
      get_bookmarked_users(user.id)

    query
    |> Ash.Query.filter(id not in ^bookmarked_users)
  end

  # defp partner_height_query(query, user) do
  #   query
  #   |> Ash.Query.filter(
  #     or: [
  #       height: [less_than_or_equal: user.maximum_partner_height],
  #       height: [greater_than_or_equal: user.minimum_partner_height]
  #     ]
  #   )
  # end

  # We use a fragment query to calculate the age of the user as
  # ash does not support using module calculations defined with calculate/3 in filter queries
  # defp partner_age_query(query, user) do
  #   conditional_partner_age_query(query, user.minimum_partner_age, user.maximum_partner_age)
  # end

  # defp conditional_partner_age_query(query, nil, nil) do
  #   query
  # end

  # defp conditional_partner_age_query(query, minimum_partner_age, nil) do
  #   query
  #   |> Ash.Query.filter(
  # fragment("date_part('year', age(current_date, ?))",
  # birthday) >= ^minimum_partner_age
  #   )
  # end

  # defp conditional_partner_age_query(query, nil, maximum_partner_age) do
  #   query
  #   |> Ash.Query.filter(
  #     fragment("date_part('year', age(current_date, ?))", birthday) <= ^maximum_partner_age
  #   )
  # end

  # defp conditional_partner_age_query(query, minimum_partner_age, maximum_partner_age) do
  #   query
  #   |> Ash.Query.filter(
  #     fragment("date_part('year', age(current_date, ?))", birthday) <= ^maximum_partner_age and
  #       fragment("date_part('year', age(current_date, ?))", birthday) >= ^minimum_partner_age
  #   )
  # end

  defp partner_gender_query(query, user) do
    query
    |> Ash.Query.filter(gender: [eq: user.partner_gender])
  end

  defp registration_partner_gender_query(query, user) do
    if user["gender"] == "" do
      query
    else
      query
      |> Ash.Query.filter(gender: [eq: user["gender"]])
    end
  end

  defp registration_partner_height_query(query, user) do
    max_height = conditional_maximum_height(user["height"], user["maximum_partner_height"])
    min_height = conditional_minimum_height(user["height"], user["minimum_partner_height"])

    query
    |> Ash.Query.filter(height <= ^max_height)
    |> Ash.Query.filter(height >= ^min_height)
  end

  defp registration_partner_age_query(query, user) do
    case convert_to_date(user["birthday"]) do
      {:ok, date} ->
        age = calculate_age(date)

        max_age = conditional_maximum_age(age, user["maximum_partner_age"])
        min_age = conditional_minimum_age(age, user["minimum_partner_age"])

        query
        |> Ash.Query.filter(
          fragment(
            "date_part('year', age(current_date, ?))",
            birthday
          ) >= ^min_age
        )
        |> Ash.Query.filter(
          fragment(
            "date_part('year', age(current_date, ?))",
            birthday
          ) <= ^max_age
        )

      _ ->
        query
    end
  end

  defp registration_partner_geo_query(query, user) do
    if user["zip_code"] == "" do
      query
    else
      nearby_zip_codes =
        get_nearby_cities(user["zip_code"], user["search_range"])
        |> Enum.map(fn city -> city.zip_code end)

      query
      |> Ash.Query.filter(zip_code: [in: nearby_zip_codes])
    end
  end

  defp conditional_maximum_age("", "") do
    Application.get_env(:animina, :default_potential_partner_maximum_age)
  end

  defp conditional_maximum_age(age, "") do
    age + Application.get_env(:animina, :default_partner_age_offset)
  end

  defp conditional_maximum_age(_, max_age) do
    String.to_integer(max_age)
  end

  defp conditional_minimum_age("", "") do
    Application.get_env(:animina, :default_potential_partner_minimum_age)
  end

  defp conditional_minimum_age(age, "") do
    age + Application.get_env(:animina, :default_partner_age_offset)
  end

  defp conditional_minimum_age(_, min_age) do
    String.to_integer(min_age)
  end

  defp conditional_maximum_height("", "") do
    #  We set the minimum height to 0m if the user does not specify a minimum height
    Application.get_env(:animina, :default_potential_partner_maximum_height)
  end

  defp conditional_maximum_height(height, "") do
    # We add a 10cm buffer to the user's height if the user does not specify a maximum height
    String.to_integer(height) +
      Application.get_env(:animina, :default_partner_height_offset)
  end

  defp conditional_maximum_height(_height, maximum_partner_height) do
    String.to_integer(maximum_partner_height)
  end

  defp conditional_minimum_height("", "") do
    # We set the minimum height to 0cm if the user does not specify a minimum height
    Application.get_env(:animina, :default_potential_partner_minimum_height)
  end

  defp conditional_minimum_height(height, "") do
    # We remove a 10cm buffer to the user's height if the user does not specify a minimum height
    String.to_integer(height) -
      Application.get_env(:animina, :default_partner_height_offset)
  end

  defp conditional_minimum_height(_, minimum_partner_height) do
    String.to_integer(minimum_partner_height)
  end

  # defp partner_geo_query(query, user) do
  #   nearby_zip_codes =
  #     get_nearby_cities(user.zip_code, user.search_range)
  #     |> Enum.map(fn city -> city.zip_code end)

  #   query
  #   |> Ash.Query.filter(zip_code: [in: nearby_zip_codes])
  # end

  # defp partner_green_flags_query(query, user) do
  #   white_flags =
  #     get_user_flags(user.id, :white)
  #     |> Enum.map(fn flag -> flag.flag_id end)

  #   query
  #   |> Ash.Query.filter(traits.color == :green and traits.flag_id in ^white_flags)
  # end

  # defp partner_red_flags_query(query, user, strict_red_flags) when strict_red_flags == true do
  #   red_flags =
  #     get_user_flags(user.id, :red)
  #     |> Enum.map(fn flag -> flag.flag_id end)

  #   query
  #   |> Ash.Query.filter(traits.color == :white and traits.flag_id not in ^red_flags)
  # end

  # defp partner_red_flags_query(query, _user, _strict_red_flags) do
  #   query
  # end

  # We use the haversine formula to get locations
  # near the current city in the search range radius
  def get_nearby_cities(zip_code, search_range) do
    search_range =
      if search_range == "" do
        Application.get_env(:animina, :default_potential_partner_search_range_in_km)
      else
        String.to_integer(search_range)
      end

    case City.by_zip_code(zip_code) do
      {:ok, current_city} ->
        City
        |> Ash.Query.filter(
          fragment(
            "acos(sin(radians(?)) * sin(radians(lat)) +
          cos(radians(?)) * cos(radians(lat)) *
          cos(radians(?) - radians(lon))) * 6731 <= ?",
            ^current_city.lat,
            ^current_city.lat,
            ^current_city.lon,
            ^search_range
          )
        )
        |> Ash.read!()

      _ ->
        # If the city is not found, we return an empty list
        []
    end
  end

  # defp get_user_flags(user_id, color) do
  #   UserFlags
  #   |> Ash.Query.for_read(:by_user_id, %{id: user_id, color: color})
  #   |> Ash.read!()
  # end

  defp get_bookmarked_users(user_id) do
    case Accounts.Bookmark.by_owner(user_id) do
      {:ok, bookmarks} ->
        Enum.map(bookmarks, fn bookmark -> bookmark.user_id end)

      _ ->
        []
    end
  end

  def convert_to_date(date_string) do
    BirthdayValidator.validate_birthday(date_string)
  end

  def calculate_age(birthdate) do
    today = Date.utc_today()
    days = Date.diff(today, birthdate)
    years = days / 365.25
    floor(years)
  end
end
