defmodule Animina.Photos.UrlSigning do
  @moduledoc """
  URL signing utilities for secure photo access.

  Generates and verifies HMAC signatures for photo URLs with daily rotation.
  """

  alias Animina.Photos.Photo

  @doc """
  Returns the secret salt for URL signing.
  Derived from the application's secret_key_base to ensure uniqueness per installation.
  """
  def url_secret_salt do
    secret_key_base = Application.get_env(:animina, AniminaWeb.Endpoint)[:secret_key_base]

    :crypto.mac(:hmac, :sha256, secret_key_base, "animina-photo-url-signing")
    |> Base.encode64()
  end

  @doc """
  Generates a signed URL path for serving a photo.
  """
  def signed_url(%Photo{} = photo, variant \\ :main) do
    filename = variant_filename(photo, variant)
    signature = compute_signature(photo.id)
    "/photos/#{signature}/#{filename}"
  end

  @doc """
  Verifies a signed URL signature for a photo ID.
  Returns `true` if the signature is valid for today.
  """
  def verify_signature(signature, photo_id) do
    expected = compute_signature(photo_id)
    Plug.Crypto.secure_compare(signature, expected)
  end

  @doc """
  Computes the HMAC signature for a photo ID using today's daily secret.
  """
  def compute_signature(photo_id) do
    daily_secret = daily_secret()

    :crypto.mac(:hmac, :sha256, daily_secret, photo_id)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  defp daily_secret do
    base_secret = url_secret_salt()
    today = Date.utc_today() |> Date.to_iso8601()
    :crypto.mac(:hmac, :sha256, base_secret, today)
  end

  defp variant_filename(%Photo{} = photo, :main), do: "#{photo.id}.webp"
  defp variant_filename(%Photo{} = photo, :thumbnail), do: "#{photo.id}_thumb.webp"
  defp variant_filename(%Photo{} = photo, :pixel), do: "#{photo.id}_pixel.webp"
  defp variant_filename(%Photo{} = photo, :review_pixel), do: "#{photo.id}_review_pixel.webp"
end
