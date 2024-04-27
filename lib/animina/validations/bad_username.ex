defmodule Animina.Validations.BadUsername do
  use Ash.Resource.Validation

  @moduledoc """
  This is a module for validating the username .
  If the username is in a list of bad usernames, it will return an error.
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
    username = changeset.attributes.username

    bad_usernames = ["my", "current_user"]

    if Ash.CiString.value(username) in bad_usernames do
      {:error, field: :username, message: "This is a bad username"}
    else
      :ok
    end
  end
end
