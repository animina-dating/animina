defmodule AniminaWeb.Helpers.UserHelpers do
  @moduledoc """
  Shared user-related view helpers used across LiveViews.
  """

  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Returns the gender symbol as a safe HTML entity (♂/♀/⚪).
  """
  def gender_icon("male"), do: raw("&#9794;")
  def gender_icon("female"), do: raw("&#9792;")
  def gender_icon(_), do: raw("&#9898;")

  @doc """
  Returns the gender symbol as plain text (for page titles, etc.).
  """
  def gender_symbol("male"), do: "♂"
  def gender_symbol("female"), do: "♀"
  def gender_symbol(_), do: "○"

  @doc """
  Extracts zip_code and city_name for a user from preloaded locations.
  """
  def get_location_info(user, city_names) do
    case user.locations do
      [%{zip_code: zip} | _] -> {zip, Map.get(city_names, zip)}
      _ -> {nil, nil}
    end
  end
end
