defmodule Animina.Reports.IdentityHash do
  @moduledoc """
  Hashing utility for identity-based persistence in the reporting system.

  All report-related persistence uses SHA-256 hashes of phone numbers and
  email addresses — never plaintext. This ensures strikes, invisibilities,
  and bans survive account deletion and follow users across re-registrations.
  """

  @doc """
  Hashes a phone number. Normalizes to E.164 format first.
  """
  def hash_phone(phone) when is_binary(phone) do
    normalized =
      case ExPhoneNumber.parse(phone, "DE") do
        {:ok, parsed} -> ExPhoneNumber.format(parsed, :e164)
        _ -> phone
      end

    sha256(normalized)
  end

  @doc """
  Hashes an email address. Downcases first.
  """
  def hash_email(email) when is_binary(email) do
    email
    |> String.downcase()
    |> sha256()
  end

  @doc """
  Returns `{phone_hash, email_hash}` for a user.
  """
  def hash_pair(user) do
    {hash_phone(user.mobile_phone), hash_email(user.email)}
  end

  defp sha256(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end
end
