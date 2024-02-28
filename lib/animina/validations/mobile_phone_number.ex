defmodule Animina.Validations.MobilePhoneNumber do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating a mobile phone number.
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
    Ash.Changeset.get_attribute(changeset, :mobile_phone)
    |> extract_ex_phone_number()
    |> validate_mobile_phone_number(opts)
  end

  defp extract_ex_phone_number(raw_attribute) do
    case ExPhoneNumber.parse(raw_attribute, "DE") do
      {:ok, phone_number} -> phone_number
      _ -> nil
    end
  end

  defp validate_mobile_phone_number(nil, opts) do
    {:error, field: opts[:attribute], message: "must be a valid phone number"}
  end

  defp validate_mobile_phone_number(ex_phone_number, opts) do
    case ExPhoneNumber.is_valid_number?(ex_phone_number) do
      false ->
        {:error, field: opts[:attribute], message: "must be a valid phone number"}

      _ ->
        case ExPhoneNumber.get_number_type(ex_phone_number) do
          :mobile -> :ok
          _ -> {:error, field: opts[:attribute], message: "must be a mobile phone number"}
        end
    end
  end
end
