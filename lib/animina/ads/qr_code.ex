defmodule Animina.Ads.QrCode do
  @moduledoc """
  QR code generation for ad campaign URLs.

  Uses external tools:
  - `qrencode` — generates QR code PNG
  - `magick` (ImageMagick) — composites heart mask overlay
  - `zbarimg` (optional) — verifies QR code decodes correctly
  """

  require Logger

  @heart_mask_path "priv/images/qr-code/heart_mask.png"
  @output_dir "uploads/qr-codes"

  @doc """
  Checks that required external tools are installed.
  Returns `:ok` or `{:error, reason}`.
  """
  def check_dependencies do
    cond do
      !command_available?("qrencode") ->
        {:error, "qrencode is not installed. Install with: brew install qrencode"}

      !command_available?("magick") ->
        {:error, "ImageMagick is not installed. Install with: brew install imagemagick"}

      true ->
        :ok
    end
  end

  @doc """
  Generates a QR code PNG for the given ad.

  Returns `{:ok, output_path}` or `{:error, reason}`.
  """
  def generate(%{url: url, number: number}) do
    with :ok <- check_dependencies() do
      code = Integer.to_string(number, 36) |> String.downcase()
      output_path = Path.join(@output_dir, "ad_#{code}.png")
      tmp_raw = Path.join(System.tmp_dir!(), "qr_raw_#{code}.png")
      heart_mask = Application.app_dir(:animina, @heart_mask_path)

      try do
        File.mkdir_p!(@output_dir)

        with :ok <- run_qrencode(tmp_raw, url),
             :ok <- run_composite(tmp_raw, heart_mask, output_path),
             :ok <- maybe_verify(output_path, url) do
          {:ok, output_path}
        end
      catch
        {:error, reason} -> {:error, reason}
      after
        File.rm(tmp_raw)
      end
    end
  end

  defp run_qrencode(output, url) do
    case System.cmd("qrencode", ["-o", output, "-l", "H", url], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {err, _} -> throw({:error, "qrencode failed: #{err}"})
    end
  end

  defp run_composite(raw, mask, output) do
    {qr_w, _qr_h} = get_image_dimensions(raw)
    {mask_w, _mask_h} = get_image_dimensions(mask)

    if qr_w == mask_w do
      # QR and mask are the same size — composite directly, no resizing needed
      case System.cmd(
             "magick",
             [raw, mask, "-gravity", "center", "-composite", output],
             stderr_to_stdout: true
           ) do
        {_, 0} -> :ok
        {err, _} -> throw({:error, "magick composite failed: #{err}"})
      end
    else
      # Fallback: resize mask to match QR size with grid-aligned snapping
      full_size = "#{qr_w}x#{qr_w}"

      case System.cmd(
             "magick",
             [
               raw,
               "(",
               mask,
               "-filter",
               "point",
               "-resize",
               full_size,
               "-channel",
               "A",
               "-threshold",
               "50%",
               "+channel",
               ")",
               "-gravity",
               "center",
               "-composite",
               output
             ],
             stderr_to_stdout: true
           ) do
        {_, 0} -> :ok
        {err, _} -> throw({:error, "magick composite failed: #{err}"})
      end
    end
  end

  defp get_image_dimensions(path) do
    case System.cmd("magick", ["identify", "-format", "%wx%h", path], stderr_to_stdout: true) do
      {dims, 0} ->
        [w, h] = dims |> String.trim() |> String.split("x") |> Enum.map(&String.to_integer/1)
        {w, h}

      {err, _} ->
        throw({:error, "magick identify failed: #{err}"})
    end
  end

  defp maybe_verify(output_path, url) do
    if command_available?("zbarimg") do
      verify_qr(output_path, url)
    else
      Logger.info("zbarimg not installed, skipping QR verification")
      :ok
    end
  end

  defp verify_qr(output_path, url) do
    case System.cmd("zbarimg", ["--quiet", "--raw", output_path], stderr_to_stdout: true) do
      {decoded, 0} ->
        decoded = String.trim(decoded)

        if decoded == url do
          :ok
        else
          File.rm(output_path)
          throw({:error, "QR verification failed: decoded '#{decoded}' != '#{url}'"})
        end

      {_, _} ->
        Logger.info("QR verification with zbarimg failed (non-zero exit), skipping")
        :ok
    end
  end

  defp command_available?(cmd) do
    case System.cmd("which", [cmd], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end
end
