defmodule Animina.Accounts.ContactBlacklistEntry do
  @moduledoc """
  Schema for contact blacklist entries.

  Each entry is either a phone number (E.164) or email address that the user
  wants to block from seeing their profile in discovery.
  """

  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: AniminaWeb.Gettext

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "contact_blacklist_entries" do
    field :entry_type, :string
    field :value, :string
    field :label, :string

    belongs_to :user, Animina.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:entry_type, :value, :label, :user_id])
    |> validate_required([:entry_type, :value, :user_id])
    |> validate_inclusion(:entry_type, ~w(phone email))
    |> validate_length(:label, max: 100)
    |> validate_value()
    |> unique_constraint(:value,
      name: :contact_blacklist_entries_user_id_value_index,
      message: dgettext("errors", "is already blocked")
    )
    |> foreign_key_constraint(:user_id)
  end

  defp validate_value(changeset) do
    case {get_field(changeset, :entry_type), get_field(changeset, :value)} do
      {"phone", value} when is_binary(value) -> validate_phone(changeset, value)
      {"email", value} when is_binary(value) -> validate_email(changeset, value)
      _ -> changeset
    end
  end

  defp validate_phone(changeset, phone) do
    case ExPhoneNumber.parse(phone, "DE") do
      {:ok, parsed} ->
        if ExPhoneNumber.is_valid_number?(parsed) do
          put_change(changeset, :value, ExPhoneNumber.format(parsed, :e164))
        else
          add_error(changeset, :value, dgettext("errors", "is not a valid phone number"))
        end

      _ ->
        add_error(changeset, :value, dgettext("errors", "is not a valid phone number"))
    end
  end

  defp validate_email(changeset, email) do
    normalized = String.downcase(email)

    changeset = put_change(changeset, :value, normalized)

    if Regex.match?(~r/^[^@,;\s]+@[^@,;\s]+$/, normalized) && String.length(normalized) <= 160 do
      changeset
    else
      add_error(changeset, :value, dgettext("errors", "is not a valid email address"))
    end
  end
end
