defmodule Animina.Repo.Migrations.ReplaceOptimizedPhotosPath do
  @moduledoc """
  Replaces the file path in the image_url for optimized photos.
  """
  use Ecto.Migration

  alias Animina.Accounts.OptimizedPhoto

  import Ecto.Query

  def up do
    if Application.get_env(:animina, :environment) == :prod do
      uploads_directory = Application.get_env(:animina, :uploads_directory)

      {:ok, optimized_photo_query} =
        Ash.Query.new(OptimizedPhoto)
        |> Ash.Query.data_layer_query()

      # query that updates the image_url
      update_image_url_query =
        from p in optimized_photo_query,
          update: [set: [image_url: fragment("replace(image_url, 'priv/static/uploads', ?)", ^uploads_directory)]]

      repo().update_all(update_image_url_query, [])
    end
  end

  def down do
    if Application.get_env(:animina, :environment) == :prod do
      uploads_directory = Application.get_env(:animina, :uploads_directory)

      {:ok, optimized_photo_query} =
        Ash.Query.new(OptimizedPhoto)
        |> Ash.Query.data_layer_query()

      # query that updates the image_url
      update_image_url_query =
        from p in optimized_photo_query,
          update: [set: [image_url: fragment("replace(image_url, ?, 'priv/static/uploads')", ^uploads_directory)]]

      repo().update_all(update_image_url_query, [])
    end
  end
end
