defmodule Animina.Servings.NsfwDetectionServing do
  @moduledoc """
  Nsfw photo detection serving
  """
  def serving do
    {:ok, model_info} = Bumblebee.load_model({:hf, "Falconsai/nsfw_image_detection"})

    {:ok, featurizer} =
      Bumblebee.load_featurizer({:hf, "google/vit-base-patch16-224"},
        module: Bumblebee.Vision.VitFeaturizer
      )

    Bumblebee.Vision.image_classification(model_info, featurizer,
      compile: [batch_size: 4],
      defn_options: [compiler: EXLA]
    )
  end
end
