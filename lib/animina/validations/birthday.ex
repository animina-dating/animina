defmodule Animina.Validations.Birthday do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the user is at least 18 years old
  """

  @impl true
  def validate(changeset, opts) do
    birthday = Ash.Changeset.get_attribute(changeset, :birthday)
    today = Date.utc_today()

    cond do
      birthday == nil ->
        :ok

      today.year - birthday.year < 18 ->
        {:error, field: opts[:attribute], message: "must be at least 18 years old"}

      true ->
        :ok
    end
  end
end
