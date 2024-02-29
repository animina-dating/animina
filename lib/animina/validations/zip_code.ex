defmodule Animina.Validations.ZipCode do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the zip code length
  """

  alias Animina.GeoData.City

  @impl true
  def init(opts) do
    case is_atom(opts[:attribute]) do
      true -> {:ok, opts}
      _ -> {:error, "attribute must be an atom!"}
    end
  end

  @impl true
  def validate(changeset, opts) do
    zip_code = Ash.Changeset.get_attribute(changeset, :zip_code)
    five_digits? = String.match?(zip_code || "", ~r/^[0-9]{5}$/)

    case {zip_code, five_digits?} do
      {nil, _} ->
        :ok

      {_, true} ->
        case valid_german_zip_code?(zip_code) do
          true -> :ok
          _ -> {:error, field: opts[:attribute], message: "must be a valid German city zip code"}
        end

      _ ->
        {:error, field: opts[:attribute], message: "must have 5 digits"}
    end
  end

  defp valid_german_zip_code?(zip_code) do
    case City.by_zip_code(zip_code) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
