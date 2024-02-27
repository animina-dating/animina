defmodule Animina.AshPhoneNumber do
  @moduledoc """
  PhoneNumber Type to store the number in a e164 format.
  """

  use Ash.Type

  @impl Ash.Type
  def storage_type(_), do: :string

  @impl Ash.Type
  def cast_input(nil, _), do: {:ok, nil}

  def cast_input(value, _) do
    ecto_type_cast = Ecto.Type.cast(:string, value)

    case ecto_type_cast do
      {:ok, raw_phone_number} ->
        case ExPhoneNumber.parse(raw_phone_number, "DE") do
          {:ok, phone_number} ->
            {:ok, ExPhoneNumber.format(phone_number, :e164)}

          _ ->
            ecto_type_cast
        end

      _ ->
        ecto_type_cast
    end
  end

  @impl Ash.Type
  def cast_stored(nil, _), do: {:ok, nil}

  def cast_stored(value, _) do
    Ecto.Type.load(:string, value)
  end

  @impl Ash.Type
  def dump_to_native(nil, _), do: {:ok, nil}

  def dump_to_native(value, _) do
    Ecto.Type.dump(:string, value)
  end
end
