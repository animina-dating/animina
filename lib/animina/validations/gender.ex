defmodule Animina.Validations.Gender do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the gender to be male, female or diverse.
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
    case Ash.Changeset.get_attribute(changeset, opts[:attribute]) do
      nil -> :ok
      "male" -> :ok
      "female" -> :ok
      "diverse" -> :ok
      _ -> {:error, field: opts[:attribute], message: "must be male, female or diverse"}
    end
  end
end
