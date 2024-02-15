defmodule Animina.Validations.MinMaxHeight do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the mimimum and maximum partner heights
  """

  @impl true
  def init(opts) do
    case is_atom(opts[:attribute]) do
      true -> {:ok, opts}
      _ -> {:error, "attribute must be an integer!"}
    end
  end

  @impl true
  def validate(changeset, opts) do
    min_height = Ash.Changeset.get_attribute(changeset, :minimum_partner_height)
    max_height = Ash.Changeset.get_attribute(changeset, :maximum_partner_height)

    cond do
      min_height == nil || max_height == nil ->
        :ok

      opts[:attribute] == :maximum_partner_height && max_height < min_height ->
        {:error,
         field: opts[:attribute], message: "must be same or higher than minimum partner height"}

      opts[:attribute] == :minimum_partner_height && min_height > max_height ->
        {:error,
         field: opts[:attribute], message: "must be same or lower than maximum partner height"}

      true ->
        :ok
    end
  end
end
