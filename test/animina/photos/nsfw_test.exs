defmodule Animina.Photos.NsfwTest do
  use ExUnit.Case, async: true

  describe "Tests for Nsfw detection using AI" do
    setup do
      [
        model: load_model()
      ]
    end

    test "The following image is not nsfw." do
    end
  end

  defp load_model do
    {:ok, %{model: model, params: _params, spec: _spec}} =
      Bumblebee.load_model({:hf, "Falconsai/nsfw_image_detection"})

    {:ok, model}
  end
end
