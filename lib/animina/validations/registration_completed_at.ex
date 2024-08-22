defmodule Animina.Validations.RegistrationCompletedAt do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the registration_completed_at .
  It has to be at least 1 minute after the current time and not more than 1 minute in the future.
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
    registration_completed_at =
      Ash.Changeset.get_attribute(changeset, opts[:attribute])

    validate_registration_completed_at(registration_completed_at)
  end

  def validate_registration_completed_at(nil) do
    :ok
  end

  def validate_registration_completed_at(registration_completed_at) do
    current_time = DateTime.utc_now()
    # 1 minute ago
    min_time = DateTime.add(current_time, -1, :minute)
    # 1 minute later
    max_time = DateTime.add(current_time, 1, :minute)

    if DateTime.compare(registration_completed_at, min_time) == :lt ||
         DateTime.compare(registration_completed_at, max_time) == :gt do
      {:error,
       field: :registration_completed_at, message: "This is not a valid registration_completed_at"}
    else
      :ok
    end
  end
end
