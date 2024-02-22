defmodule Animina.Validations.PostalCode do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the postal code length
  """

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

    cond do
      zip_code == nil ->
        :ok

      ! String.match?(zip_code, ~r/\A [0-9]{5} \z/x) ->
        {:error, field: opts[:attribute], message: "must have 5 digits"}

      true ->
        :ok
    end
  end
end
