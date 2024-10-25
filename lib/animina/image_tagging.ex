defmodule Animina.ImageTagging do
  @moduledoc """
  This module is responsible for tagging images using the Llava model.
  """
  alias Animina.Traits.Flag

  def auto_tag_image(image) do
    new_image = "priv/static/uploads/#{image}"

    tmp_image_path = "/tmp/test-photo.jpg"
    File.cp!(new_image, tmp_image_path)

    {:ok, binary} = File.read(tmp_image_path)

    photo = Base.encode64(binary)

    system_flags =
      Flag.read!()
      |> Enum.map(fn flag -> Ash.CiString.value(flag.name) end)

    string_flags = Enum.join(system_flags, ", ")

    prompt = """
    These are the available system tags #{string_flags}.


    The events in the image may closely relate to one or two of the system flags.


    if events in the image are not relevant to any of the flags, please do not tag it with any flags.Just retun an empty array, and description of the image.


    You should return the flags as an array of the flag names and a description of the image.


    The response should be in the following format always:
    Flags: [Flag1, Flag2]
    Description: Description of the image
    """

    client = Ollama.init()

    {:ok, response} =
      Ollama.chat(client,
        model: "llava:7b",
        messages: [
          %{role: "system", content: prompt, images: [photo]}
        ]
      )

    {flag, description} = parse_response(response["message"]["content"])

    {flag, description}
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
      if flags_line do
        flags_line
        |> String.replace("Flags: [", "")
        |> String.replace("]", "")
        |> String.replace("\"", "")
        |> String.split(", ")
      else
        []
      end

    description =
      if description_line do
        String.replace(description_line, "Description: ", "")
      else
        ""
      end

    {flags, description}
  end
end
