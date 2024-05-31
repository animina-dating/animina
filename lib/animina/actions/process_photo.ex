defmodule Animina.Actions.ProcessPhoto do
  @moduledoc """
  This is the Process Photo action module
  """
  use Ash.Resource.ManualUpdate

  alias Animina.Accounts

  require Logger

  @impl true
  def update(changeset, _, _) do
    disable_ml_features = System.get_env("DISABLE_ML_FEATURES", nil)

    with false <- disable_ml_features == true,
         {:ok, photo} <-
           changeset.data
           |> Ash.Changeset.for_update(:review, %{})
           |> Accounts.update(authorize?: false) do
      # Fetch and read the photo file
      dest = get_upload_dir(photo.filename)

      # Create a temporary file with the same extension as the original image
      extname = Path.extname(photo.filename)
      {:ok, temp_file} = Briefly.create(extname: extname)

      # Resize the image to a width of 224 pixels while maintaining the aspect ratio
      dest
      |> Mogrify.open()
      |> Mogrify.resize("224x")
      |> Mogrify.save(path: temp_file)

      # Read the resized image from the temporary file
      image = StbImage.read_file!(temp_file)

      # Classify image using Nx.Serving
      output =
        Nx.Serving.batched_run(NsfwDetectionServing, image)

      # Ensure the temporary file is deleted
      File.rm(temp_file)

      # Get the normal label score
      normal_label_score =
        Enum.filter(output.predictions, fn prediction -> prediction.label == "normal" end)
        |> Enum.at(0)
        |> Map.get(:score)

      # Get the nsfw label score
      nsfw_label_score =
        Enum.filter(output.predictions, fn prediction -> prediction.label == "nsfw" end)
        |> Enum.at(0)
        |> Map.get(:score)

      # Approve normal photo, reject otherwise
      if normal_label_score > nsfw_label_score do
        photo
        |> Ash.Changeset.for_update(:approve, %{})
        |> Accounts.update(authorize?: false)
      else
        photo
        |> Ash.Changeset.for_update(:nsfw, %{})
        |> Accounts.update(authorize?: false)
      end

      {:ok, changeset.data}
    else
      true ->
        {:ok, changeset.data}

      {:error, error} ->
        Logger.info(
          "[#{__MODULE__}] failed to update photo status to in_review. Error #{inspect(error)}"
        )

        {:error, changeset.data}
    end
  end

  defp get_upload_dir(filename) do
    Path.join(
      Application.app_dir(:animina, "priv/static/uploads"),
      Path.basename(filename)
    )
  end
end
