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
  def validate(changeset, opts, _context) do
    username =
      Ash.Changeset.get_attribute(changeset, opts[:attribute])

    bad_usernames = [
      "my",
      "current_user",
      "profile",
      "beta",
      "test",
      "new",
      "alpha",
      "next",
      "Stefan",
      "Stephan",
      "Aurelius",
      "Juna",
      "Miri",
      "Miriam",
      "aw",
      "jw",
      "sw",
      "up"
    ]

    case more_than_2_chars?(username) do
      false ->
        {:error, field: :username, message: "Username must be at least 2 characters long"}

      true ->
        if username &&
             (Ash.CiString.value(username) in bad_usernames or
                has_at?(Ash.CiString.value(username))) do
          {:error, field: :username, message: "This is a bad username"}
        else
          :ok
        end
    end
  end

  def has_at?(string) do
    String.contains?(string, "@")
  end

  def more_than_2_chars?(nil) do
    false
  end

  def more_than_2_chars?(string) do
    string && String.length(Ash.CiString.value(string)) > 2
  end
end
