defmodule Animina.Validations.PhoneNumber do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating a phone number.
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
    raw_phone_number = Ash.Changeset.get_attribute(changeset, :mobile_phone)

    case ExPhoneNumber.parse(raw_phone_number, "DE") do
      {:ok, phone_number} ->
        case ExPhoneNumber.is_valid_number?(phone_number) do
          false -> {:error, field: opts[:attribute], message: "must be a valid phone number"}
          _ -> :ok
        end

      _ ->
        {:error, field: opts[:attribute], message: "must be a valid phone number"}
    end
  end
end
