defmodule Animina.GeoDataTest do
  use Animina.DataCase

  alias Animina.GeoData
  alias Animina.GeoData.{Country, City}

  describe "countries" do
    test "create_country/1 creates a country with valid attrs" do
      assert {:ok, %Country{} = country} =
               GeoData.create_country(%{name: "Austria", code: "AT"})

      assert country.name == "Austria"
      assert country.code == "AT"
    end

    test "create_country/1 uppercases the code" do
      assert {:ok, %Country{} = country} =
               GeoData.create_country(%{name: "France", code: "fr"})

      assert country.code == "FR"
    end

    test "create_country/1 enforces unique code constraint" do
      assert {:ok, _} = GeoData.create_country(%{name: "Austria", code: "AT"})

      assert {:error, changeset} =
               GeoData.create_country(%{name: "Österreich", code: "AT"})

      assert %{code: ["has already been taken"]} = errors_on(changeset)
    end

    test "create_country/1 validates required fields" do
      assert {:error, changeset} = GeoData.create_country(%{})
      assert %{name: ["can't be blank"], code: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_country/1 validates code length" do
      assert {:error, changeset} =
               GeoData.create_country(%{name: "Germany", code: "DEU"})

      assert %{code: ["should be 2 character(s)"]} = errors_on(changeset)
    end

    test "get_country!/1 returns the country" do
      {:ok, country} = GeoData.create_country(%{name: "Austria", code: "AT"})
      assert GeoData.get_country!(country.id).id == country.id
    end

    test "get_country_by_code/1 returns the country (case-insensitive)" do
      {:ok, country} = GeoData.create_country(%{name: "Austria", code: "AT"})
      assert GeoData.get_country_by_code("AT").id == country.id
      assert GeoData.get_country_by_code("at").id == country.id
    end

    test "list_countries/0 returns all countries" do
      initial_count = length(GeoData.list_countries())
      {:ok, _} = GeoData.create_country(%{name: "Austria", code: "AT"})
      {:ok, _} = GeoData.create_country(%{name: "France", code: "FR"})
      assert length(GeoData.list_countries()) == initial_count + 2
    end

    test "seeded Germany country exists" do
      country = GeoData.get_country_by_code("DE")
      assert country != nil
      assert country.name == "Germany"
    end
  end

  describe "cities" do
    setup do
      {:ok, country} = GeoData.create_country(%{name: "Austria", code: "AT"})
      %{country: country}
    end

    test "create_city/1 creates a city with valid attrs", %{country: country} do
      attrs = %{
        name: "Wien",
        zip_code: "01010",
        county: "Wien",
        federal_state: "Wien",
        lat: 48.208174,
        lon: 16.373819,
        country_id: country.id
      }

      assert {:ok, %City{} = city} = GeoData.create_city(attrs)
      assert city.name == "Wien"
      assert city.zip_code == "01010"
      assert city.county == "Wien"
      assert city.federal_state == "Wien"
      assert_in_delta city.lat, 48.208174, 0.0001
      assert_in_delta city.lon, 16.373819, 0.0001
      assert city.country_id == country.id
    end

    test "create_city/1 validates required fields" do
      assert {:error, changeset} = GeoData.create_city(%{})

      errors = errors_on(changeset)
      assert errors[:name] == ["can't be blank"]
      assert errors[:zip_code] == ["can't be blank"]
      assert errors[:county] == ["can't be blank"]
      assert errors[:federal_state] == ["can't be blank"]
      assert errors[:lat] == ["can't be blank"]
      assert errors[:lon] == ["can't be blank"]
      assert errors[:country_id] == ["can't be blank"]
    end

    test "create_city/1 validates zip_code format", %{country: country} do
      attrs = %{
        name: "Wien",
        zip_code: "1234",
        county: "Wien",
        federal_state: "Wien",
        lat: 48.208174,
        lon: 16.373819,
        country_id: country.id
      }

      assert {:error, changeset} = GeoData.create_city(attrs)
      assert %{zip_code: ["must be a 5-digit zip code"]} = errors_on(changeset)

      # Too long
      assert {:error, changeset} =
               GeoData.create_city(%{attrs | zip_code: "123456"})

      assert %{zip_code: ["must be a 5-digit zip code"]} = errors_on(changeset)

      # Non-numeric
      assert {:error, changeset} =
               GeoData.create_city(%{attrs | zip_code: "ABCDE"})

      assert %{zip_code: ["must be a 5-digit zip code"]} = errors_on(changeset)
    end

    test "create_city/1 enforces unique zip_code constraint", %{country: country} do
      attrs = %{
        name: "Wien",
        zip_code: "01010",
        county: "Wien",
        federal_state: "Wien",
        lat: 48.208174,
        lon: 16.373819,
        country_id: country.id
      }

      assert {:ok, _} = GeoData.create_city(attrs)

      assert {:error, changeset} =
               GeoData.create_city(%{attrs | name: "Wien Innere Stadt"})

      assert %{zip_code: ["has already been taken"]} = errors_on(changeset)
    end

    test "get_city!/1 returns the city", %{country: country} do
      {:ok, city} = create_city(country)
      assert GeoData.get_city!(city.id).id == city.id
    end

    test "get_city_by_zip_code/1 returns the city", %{country: country} do
      {:ok, city} = create_city(country)
      assert GeoData.get_city_by_zip_code("01010").id == city.id
    end

    test "get_city_by_zip_code/1 returns nil for unknown zip" do
      assert GeoData.get_city_by_zip_code("99999") == nil
    end

    test "list_cities/0 returns all cities", %{country: country} do
      initial_count = length(GeoData.list_cities())
      {:ok, _} = create_city(country)

      {:ok, _} =
        GeoData.create_city(%{
          name: "Graz",
          zip_code: "08010",
          county: "Graz",
          federal_state: "Steiermark",
          lat: 47.070714,
          lon: 15.439504,
          country_id: country.id
        })

      assert length(GeoData.list_cities()) == initial_count + 2
    end

    test "list_cities_by_country/1 returns cities for a country", %{country: country} do
      {:ok, _} = create_city(country)
      {:ok, other_country} = GeoData.create_country(%{name: "France", code: "FR"})

      {:ok, _} =
        GeoData.create_city(%{
          name: "Paris",
          zip_code: "75001",
          county: "Paris",
          federal_state: "Île-de-France",
          lat: 48.860611,
          lon: 2.337644,
          country_id: other_country.id
        })

      assert length(GeoData.list_cities_by_country(country.id)) == 1
      assert length(GeoData.list_cities_by_country(other_country.id)) == 1
    end

    test "city belongs_to country preload", %{country: country} do
      {:ok, city} = create_city(country)
      city = Repo.preload(city, :country)
      assert city.country.id == country.id
      assert city.country.code == "AT"
    end

    test "seeded German cities exist" do
      # The seed migration should have inserted 8000+ German cities
      germany = GeoData.get_country_by_code("DE")
      german_cities = GeoData.list_cities_by_country(germany.id)
      assert length(german_cities) > 8000

      # Check a known German city by zip code
      berlin = GeoData.get_city_by_zip_code("10115")
      assert berlin != nil
      assert berlin.country_id == germany.id
    end
  end

  defp create_city(country) do
    GeoData.create_city(%{
      name: "Wien",
      zip_code: "01010",
      county: "Wien",
      federal_state: "Wien",
      lat: 48.208174,
      lon: 16.373819,
      country_id: country.id
    })
  end
end
