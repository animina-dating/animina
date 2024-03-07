defmodule Animina.Validations.Birthday do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the user is at least 18 years old
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
    today = Date.utc_today()

    case Ash.Changeset.get_attribute(changeset, opts[:attribute]) do
      %Date{} = birthday ->
        case Date.compare(
               Date.from_erl!({birthday.year + 18, birthday.month, birthday.day}),
               today
             ) do
          :gt -> {:error, field: opts[:attribute], message: "must be at least 18 years old"}
          _ -> :ok
        end

      _ ->
        :ok
    end
  end
end
