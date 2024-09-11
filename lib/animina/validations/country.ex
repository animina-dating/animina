defmodule Animina.Validations.Country do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the country.
  If the country is not in a list of valid countries, it will return an error.
  """

  @impl true
  def init(opts) do
    case is_atom(opts[:attribute]) do
      true -> {:ok, opts}
      _ -> {:error, "attribute must be an atom!"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    country =
      Ash.Changeset.get_attribute(changeset, opts[:attribute])

    countries_supported = ["Germany"]

    if country &&
         country not in countries_supported do
      {:error, field: :username, message: "This is an unsupported country"}
    else
      :ok
    end
  end
end
