defmodule Mix.Tasks.Uploads.Clear do
  @shortdoc "Clears all uploaded images from uploads/ and tmp/test_uploads/"
  @moduledoc """
  Removes all files from the uploads directory and test uploads directory.

  ## Usage

      mix uploads.clear

  This is intended for development/test environments only.
  """
  use Mix.Task

  def run(_args) do
    uploads_dir = Application.get_env(:animina, :upload_dir, "uploads")
    test_uploads_dir = "tmp/test_uploads"

    clear_directory(uploads_dir)
    clear_directory(test_uploads_dir)
  end

  defp clear_directory(dir) do
    if File.exists?(dir) do
      Mix.shell().info("Clearing #{dir}/...")
      File.rm_rf!(dir)
      File.mkdir_p!(dir)
      Mix.shell().info("Cleared #{dir}/")
    else
      Mix.shell().info("Directory #{dir}/ does not exist, skipping")
    end
  end
end
