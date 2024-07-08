defmodule Animina.Validations.BadPassword do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the password. It checks if the
  password is in a list of popular passwords and if it is long enough.
  """

  alias Animina.Accounts.BadPassword

  @impl true
  def init(opts) do
    case is_atom(opts[:attribute]) do
      true -> {:ok, opts}
      _ -> {:error, "attribute must be an atom!"}
    end
  end

  @impl true
  def validate(changeset, _opts, _context) do
    case changeset.arguments do
      %{password: nil} ->
        :ok

      %{password: password} ->
        case {String.length(password), BadPassword.by_value(password)} do
          {8, _} ->
            {:error, field: :password, message: "must be at least 9 characters long"}

          {_, {:ok, _}} ->
            {:error, field: :password, message: "must not be a popular one"}

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end
end
