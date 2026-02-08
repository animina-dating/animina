defmodule Animina.Accounts.ContactBlacklist do
  @moduledoc """
  Context for managing contact blacklist entries.

  Users can block phone numbers and email addresses to prevent contacts
  they know in real life from seeing them in discovery (and vice versa).
  """

  import Ecto.Query

  alias Animina.Accounts.ContactBlacklistEntry
  alias Animina.Accounts.User
  alias Animina.Repo

  @max_entries 50

  def max_entries, do: @max_entries

  @doc """
  Lists all blacklist entries for a user, newest first.
  """
  def list_entries(%User{id: user_id}) do
    from(e in ContactBlacklistEntry,
      where: e.user_id == ^user_id,
      order_by: [desc: e.inserted_at, desc: e.id]
    )
    |> Repo.all()
  end

  @doc """
  Counts blacklist entries for a user.
  """
  def count_entries(%User{id: user_id}) do
    from(e in ContactBlacklistEntry,
      where: e.user_id == ^user_id,
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Adds a blacklist entry for a user.

  Auto-detects phone vs email by checking for `@` in the value.
  Returns `{:error, :limit_reached}` if the user has reached the maximum.
  """
  def add_entry(%User{id: user_id} = user, attrs) do
    if count_entries(user) >= @max_entries do
      {:error, :limit_reached}
    else
      value = Map.get(attrs, :value) || Map.get(attrs, "value") || ""
      entry_type = detect_type(value)

      %ContactBlacklistEntry{user_id: user_id}
      |> ContactBlacklistEntry.changeset(Map.put(attrs, :entry_type, entry_type))
      |> Repo.insert()
    end
  end

  @doc """
  Removes a blacklist entry, scoped to the given user.
  """
  def remove_entry(%User{id: user_id}, entry_id) do
    case Repo.get_by(ContactBlacklistEntry, id: entry_id, user_id: user_id) do
      nil -> {:error, :not_found}
      entry -> Repo.delete(entry)
    end
  end

  @doc """
  Returns a changeset for form rendering.
  """
  def change_entry(entry \\ %ContactBlacklistEntry{}, attrs \\ %{}) do
    ContactBlacklistEntry.changeset(entry, attrs)
  end

  @doc """
  Normalizes a raw phone input to E.164 format.
  Returns `{:ok, e164}` or `{:error, reason}`.
  """
  def normalize_phone(raw) when is_binary(raw) do
    case ExPhoneNumber.parse(raw, "DE") do
      {:ok, parsed} ->
        if ExPhoneNumber.is_valid_number?(parsed) do
          {:ok, ExPhoneNumber.format(parsed, :e164)}
        else
          {:error, :invalid}
        end

      _ ->
        {:error, :invalid}
    end
  end

  defp detect_type(value) when is_binary(value) do
    if String.contains?(value, "@"), do: "email", else: "phone"
  end

  defp detect_type(_), do: "phone"
end
