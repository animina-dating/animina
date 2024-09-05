defmodule Animina.ImageTagging do
  alias Animina.Traits.Flag

  def tag_image_using_llava(image) do
    IO.inspect(image, label: "Image")

    system_flags =
      Flag.read!()
      |> Enum.map(fn flag -> Ash.CiString.value(flag.name) end)

    string_flags = Enum.join(system_flags, ", ")

    IO.inspect(string_flags, label: "String Flags")

    prompt = """
    Tag this image #{image} with the following system flags #{string_flags}. The image may closely relate to one or two of the system flags.

    Tag the image with the relevant flags.

    if the image is not relevant to any of the flags, please do not tag it with any flags.


    ONLY RETURN THE RELEVANT FLAGS TO THE IMAGE. DO NOT RETURN FLAGS THAT ARE NOT RELEVANT TO THE IMAGE.

    You should return the flags as an array of the flag names and a description of the image.

    The response should be in the following format:
    Flags: [Flag1, Flag2]
    Description: Description of the image
    """

    client = Ollama.init()

    {:ok, response} =
      Ollama.completion(client,
        model: "llava:7b",
        prompt: prompt
      )

    {flag, description} = parse_response(response["response"])

    {flag, description}
  end

  def test() do
    # priv/static/images/hike.jpg
    image = "images/hike.jpg"

    tag_image_using_llava(image)
  end

  defp parse_response(response) do
    lines =
      response
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    flags_line = Enum.find(lines, fn line -> String.starts_with?(line, "Flags: ") end)
    description_line = Enum.find(lines, fn line -> String.starts_with?(line, "Description: ") end)

    flags =
      flags_line
      |> String.replace("Flags: [", "")
      |> String.replace("]", "")
      |> String.replace("\"", "")
      |> String.split(", ")

    description =
      description_line
      |> String.replace("Description: ", "")

    {flags, description}
  end
end