defmodule AniminaWeb.PhotoController do
  @moduledoc """
  Serves processed photos with signed URL verification.

  URLs follow the pattern: `/photos/:signature/:filename`
  where filename is `{photo_id}.webp` or `{photo_id}_pixelated.webp`.
  """

  use AniminaWeb, :controller

  alias Animina.Photos

  def show(conn, %{"signature" => signature, "filename" => filename}) do
    with {:ok, photo_id, variant} <- parse_filename(filename),
         true <- Photos.verify_signature(signature, photo_id),
         %Photos.Photo{} = photo <- Photos.get_photo(photo_id),
         true <- Photos.processed_file_available?(photo.state) do
      serve_photo(conn, photo, variant)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> text("Not found")
    end
  end

  defp serve_photo(conn, photo, variant) do
    # If photo is NSFW and the requested variant is :main, serve the pixelated version instead
    actual_variant = if photo.nsfw and variant == :main, do: :pixelated, else: variant

    path = Photos.processed_path(photo.id, actual_variant)

    if File.exists?(path) do
      conn
      |> put_resp_header("content-type", "image/webp")
      |> put_resp_header("cache-control", "public, max-age=86400")
      |> send_file(200, path)
    else
      conn
      |> put_status(:not_found)
      |> text("Not found")
    end
  end

  defp parse_filename(filename) do
    cond do
      String.ends_with?(filename, "_pixelated.webp") ->
        photo_id = String.replace_trailing(filename, "_pixelated.webp", "")
        {:ok, photo_id, :pixelated}

      String.ends_with?(filename, "_thumb.webp") ->
        photo_id = String.replace_trailing(filename, "_thumb.webp", "")
        {:ok, photo_id, :thumbnail}

      String.ends_with?(filename, ".webp") ->
        photo_id = String.replace_trailing(filename, ".webp", "")
        {:ok, photo_id, :main}

      true ->
        {:error, :invalid_filename}
    end
  end
end
