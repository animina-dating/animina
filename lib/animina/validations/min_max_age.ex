defmodule Animina.Validations.MinMaxAge do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the mimimum and maximum partner ages
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
    min_age = Ash.Changeset.get_attribute(changeset, :minimum_partner_age)
    max_age = Ash.Changeset.get_attribute(changeset, :maximum_partner_age)

    cond do
      min_age == nil || max_age == nil ->
        :ok

      opts[:attribute] == :maximum_partner_age && max_age < min_age ->
        {:error,
         field: opts[:attribute], message: "must be same or higher than minimum partner age"}

      opts[:attribute] == :minimum_partner_age && min_age > max_age ->
        {:error,
         field: opts[:attribute], message: "must be same or lower than maximum partner age"}

      true ->
        :ok
    end
  end
end
