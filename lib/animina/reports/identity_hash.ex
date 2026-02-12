defmodule Animina.Reports.IdentityHash do
  @moduledoc """
  SHA-256 identity hashing for the reporting system.

  All report-related persistence (strikes, invisibilities, bans) uses
  hashed phone numbers and emails — never plaintext. This ensures
  data survives account deletion and follows users across re-registrations.

  - Phone: normalized to E.164 format, then SHA-256 hex-encoded
  - Email: downcased, then SHA-256 hex-encoded
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
