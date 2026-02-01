defmodule Animina.GeoData.City do
  @moduledoc """
  Schema for city reference data with geographic coordinates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cities" do
    field :name, :string
    field :zip_code, :string
    field :county, :string
    field :federal_state, :string
    field :lat, :float
    field :lon, :float

    belongs_to :country, Animina.GeoData.Country

    timestamps()
  end

  @required_fields ~w(name zip_code county federal_state lat lon country_id)a

  def changeset(city, attrs) do
    city
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_format(:zip_code, ~r/^\d{5}$/, message: "must be a 5-digit zip code")
    |> unique_constraint(:zip_code)
    |> foreign_key_constraint(:country_id)
  end
end
