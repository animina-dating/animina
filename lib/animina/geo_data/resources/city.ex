defmodule Animina.GeoData.City do
  @moduledoc """
  Cities.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.GeoData

  postgres do
    table "geo_data_cities"
    repo Animina.Repo
  end

  code_interface do
    domain Animina.GeoData
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_zip_code, get_by: [:zip_code], action: :read
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :zip_code,
        :county,
        :federal_state,
        :lat,
        :lon
      ]

      primary? true
    end

    update :update do
      accept [
        :name,
        :zip_code,
        :county,
        :federal_state,
        :lat,
        :lon
      ]

      primary? true
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :ci_string, allow_nil?: false
    attribute :zip_code, :string, allow_nil?: false
    attribute :county, :ci_string, allow_nil?: false
    attribute :federal_state, :ci_string, allow_nil?: false
    attribute :lat, :float, allow_nil?: false
    attribute :lon, :float, allow_nil?: false
  end

  identities do
    identity :unique_zip_code, [:zip_code]
  end
end
