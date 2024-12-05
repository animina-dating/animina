defmodule Animina.PathHelper do
  @moduledoc """
  String helper functions.
  """

  @doc """
  Returns an upload path depending on the environment.
  """
  def uploads_path do
    uploads_directory = Application.get_env(:animina, :uploads_directory) || "/uploads"

    case Application.get_env(:animina, :environment) do
      :test -> Application.app_dir(:animina, uploads_directory)
      :dev -> Application.app_dir(:animina, uploads_directory)
      _ -> uploads_directory
    end
  end
end
