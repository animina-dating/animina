defmodule AniminaWeb.AdQrController do
  @moduledoc """
  Serves QR code PNG files for ad campaigns.
  """

  use AniminaWeb, :controller

  alias Animina.Ads
  alias Animina.Ads.QrCode

  def download(conn, %{"id" => id}) do
    case Ads.get_ad(id) do
      %{qr_code_path: path} when is_binary(path) ->
        if File.exists?(path) do
          conn
          |> put_resp_header("content-type", "image/png")
          |> put_resp_header(
            "content-disposition",
            "attachment; filename=\"#{Path.basename(path)}\""
          )
          |> send_file(200, path)
        else
          conn |> put_status(:not_found) |> text("QR code file not found")
        end

      _ ->
        conn |> put_status(:not_found) |> text("Not found")
    end
  end

  def download_sized(conn, %{"id" => id, "size" => size_str}) do
    with {size, ""} <- Integer.parse(size_str),
         true <- size >= 100 and size <= 10_000,
         %{qr_code_path: path} when is_binary(path) <- Ads.get_ad(id),
         true <- File.exists?(path),
         {:ok, tmp_path} <- QrCode.resize(path, size) do
      conn =
        conn
        |> put_resp_header("content-type", "image/png")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"qr_#{size}x#{size}.png\""
        )
        |> send_file(200, tmp_path)

      File.rm(tmp_path)
      conn
    else
      false ->
        conn |> put_status(:not_found) |> text("QR code file not found")

      nil ->
        conn |> put_status(:not_found) |> text("Not found")

      %{qr_code_path: _} ->
        conn |> put_status(:not_found) |> text("Not found")

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> text("Resize failed: #{reason}")

      _ ->
        conn |> put_status(:bad_request) |> text("Invalid size (must be 100–10000)")
    end
  end

  def show(conn, %{"id" => id}) do
    case Ads.get_ad(id) do
      %{qr_code_path: path} when is_binary(path) ->
        if File.exists?(path) do
          conn
          |> put_resp_header("content-type", "image/png")
          |> put_resp_header("cache-control", "public, max-age=86400")
          |> send_file(200, path)
        else
          conn |> put_status(:not_found) |> text("QR code file not found")
        end

      _ ->
        conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
