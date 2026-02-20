defmodule AniminaWeb.AdQrController do
  @moduledoc """
  Serves QR code PNG files for ad campaigns.
  """

  use AniminaWeb, :controller

  alias Animina.Ads

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
