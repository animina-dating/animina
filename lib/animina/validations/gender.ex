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
  def validate(changeset, opts) do
    gender = Ash.Changeset.get_attribute(changeset, :gender)

    case gender do
      nil -> :ok
      "male" -> :ok
      "female" -> :ok
      "diverse" -> :ok
      _ -> {:error, field: opts[:attribute], message: "must be a valide gender"}
    end
  end
end
