defmodule Animina.GeoData.City do
  @moduledoc """
  Cities.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :name, :ci_string, allow_nil?: false
    attribute :zip_code, :string, allow_nil?: false
    attribute :county, :ci_string, allow_nil?: false
    attribute :federal_state, :ci_string, allow_nil?: false
    attribute :lat, :float, allow_nil?: false
    attribute :lon, :float, allow_nil?: false
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  code_interface do
    define_for Animina.GeoData
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_zip_code, get_by: [:zip_code], action: :read
  end

  identities do
    identity :unique_zip_code, [:zip_code]
  end

  postgres do
    table "geo_data_cities"
    repo Animina.Repo
  end
end
