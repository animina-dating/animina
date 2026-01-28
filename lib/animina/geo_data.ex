defmodule Animina.GeoData do
  import Ecto.Query

  alias Animina.Repo
  alias Animina.GeoData.{Country, City}

  # Countries

  def create_country(attrs) do
    %Country{}
    |> Country.changeset(attrs)
    |> Repo.insert()
  end

  def get_country!(id), do: Repo.get!(Country, id)

  def get_country_by_code(code) do
    code = String.upcase(code)
    Repo.get_by(Country, code: code)
  end

  def list_countries, do: Repo.all(Country)

  # Cities

  def create_city(attrs) do
    %City{}
    |> City.changeset(attrs)
    |> Repo.insert()
  end

  def get_city!(id), do: Repo.get!(City, id)

  def get_city_by_zip_code(zip_code) do
    Repo.get_by(City, zip_code: zip_code)
  end

  def list_cities, do: Repo.all(City)

  def list_cities_by_country(country_id) do
    City
    |> where([c], c.country_id == ^country_id)
    |> Repo.all()
  end
end
