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

      String.length(zip_code) < 5 || String.length(zip_code) > 5 ->
        {:error, field: opts[:attribute], message: "length must be 5"}

      true ->
        :ok
    end
  end
end
