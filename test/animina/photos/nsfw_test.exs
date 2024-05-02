defmodule Animina.Photos.NsfwTest do
  use ExUnit.Case, async: true

  @moduletag timeout: 600_000

  if System.get_env("DISABLE_ML_FEATURES") == true do
    describe "Tests for Nsfw photos detection using AI" do
      setup do
        if System.get_env("DISABLE_ML_FEATURES") do
          {:ok, skip: true}
        else
          [
            serving: load_serving(),
            nsfw_photo: load_nsfw_photo(),
            sfw_photo: load_sfw_photo()
          ]
        end
      end

      test "The following photo is not safe for work.", %{
        nsfw_photo: nsfw_photo,
        serving: serving
      } do
        image = StbImage.to_nx(nsfw_photo)

        output = Nx.Serving.run(serving, image)

        normal_label_score =
          Enum.filter(output.predictions, fn prediction -> prediction.label == "normal" end)
          |> Enum.at(0)
          |> Map.get(:score)

        nsfw_label_score =
          Enum.filter(output.predictions, fn prediction -> prediction.label == "nsfw" end)
          |> Enum.at(0)
          |> Map.get(:score)

        assert nsfw_label_score > normal_label_score
      end

      test "The following photo is safe for work.", %{
        sfw_photo: sfw_photo,
        serving: serving
      } do
        image = StbImage.to_nx(sfw_photo)

        output = Nx.Serving.run(serving, image)

        normal_label_score =
          Enum.filter(output.predictions, fn prediction -> prediction.label == "normal" end)
          |> Enum.at(0)
          |> Map.get(:score)

        nsfw_label_score =
          Enum.filter(output.predictions, fn prediction -> prediction.label == "nsfw" end)
          |> Enum.at(0)
          |> Map.get(:score)

        assert nsfw_label_score < normal_label_score
      end
    end

    defp load_serving do
      {:ok, model_info} = Bumblebee.load_model({:hf, "Falconsai/nsfw_image_detection"})
      {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "google/vit-base-patch16-224"})

      Bumblebee.Vision.image_classification(model_info, featurizer,
        compile: [batch_size: 1],
        defn_options: [compiler: EXLA]
      )
    end

    defp load_nsfw_photo do
      url =
        "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/fb42e162-8d65-4b9c-b468-2a232a1d8800/original=true/156217.jpeg"

      download_photo(url, "nsfw.png")
      |> StbImage.read_file!()
    end

    defp load_sfw_photo do
      url =
        "https://images.unsplash.com/photo-1610552050890-fe99536c2615?q=80&w=2707&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

      download_photo(url, "sfw.png")
      |> StbImage.read_file!()
    end

    defp download_photo(url, filename) do
      %HTTPoison.Response{body: body} = HTTPoison.get!(url)

      dest =
        System.tmp_dir!()
        |> Path.join(filename)

      File.write!(dest, body)

      dest
    end
  end
end
