defmodule Animina.GeoData do
  @moduledoc """
  This is the GeoData module.
  """

  use Ash.Domain

  resources do
    resource Animina.GeoData.City
  end
end
