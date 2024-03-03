defmodule Animina.Validations.MustBeTrue do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating that a boolean attribute is true.
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
    case Ash.Changeset.get_attribute(changeset, opts[:attribute]) do
      nil -> :ok
      true -> :ok
      _ -> {:error, field: opts[:attribute], message: "must be true"}
    end
  end
end
