defmodule Animina.ImageTagging do
  alias Animina.Traits.Flag

  def tag_image_using_llava(image, system_flags) do
    prompt = """
    Tag the image with the following labels:
    Image: #{image}
    Flags: #{system_flags}

    Make sure you tag it with only one or two flags and make sure the flags are relevant to the image.

    ONLY RETURN THE RELEVANT FLAGS TO THE IMAGE. DO NOT RETURN FLAGS THAT ARE NOT RELEVANT TO THE IMAGE.

    You should return the flags as an array of the flag names and a description of the image.

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
    IO.inspect(flag)
    IO.inspect(description)
  end

  def test() do
    # priv/static/images/hike.jpg
    image = "images/hike.jpg"

    system_flags =
      Flag.read!()
      |> Enum.map(fn flag -> Ash.CiString.value(flag.name) end)

    string_flags = Enum.join(system_flags, ", ")

    IO.inspect(string_flags)

    tag_image_using_llava(image, string_flags)
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
