defmodule Animina.ChatCompletion do
  @moduledoc """
  This module is responsible for generating a chat message for a dating app.
  """
  alias Animina.Accounts.User
  alias Animina.Narratives.Story
  alias Animina.Traits.UserFlags

  def prompt(
        user,
        potential_partner,
        user_white_flags,
        potential_partner_white_flags,
        user_stories,
        potential_partner_stories
      ) do
    "I want to send a first chat message on a dating app to a potential partner. My name is #{user.name}, and I am a #{user.gender}. The potential partner’s name is #{potential_partner.name}, and they are #{potential_partner.gender}.

Here’s some more context:

The potential partner's profile mentions the following stories: #{potential_partner_stories}.
My profile lists these stories: #{user_stories}.
The potential partner has the following interests: #{potential_partner_white_flags}.
Here is a list of my interests: #{user_white_flags}.
Can you create a positive and possibly funny first chat message using this information?,
ensure the message is respectful and engaging and that is is just one , not many options."
  end

  def test do
    user = User.read!() |> Enum.random()
    potential_partner = User.read!() |> Enum.random()

    request_message(user, potential_partner)
  end

  def request_message(user, potential_partner) do
    user_white_flags = get_white_flags(user)
    potential_partner_white_flags = get_white_flags(potential_partner)

    user_stories = get_stories(user)
    potential_partner_stories = get_stories(potential_partner)

    prompt =
      prompt(
        user,
        potential_partner,
        user_white_flags,
        potential_partner_white_flags,
        user_stories,
        potential_partner_stories
      )

    client = Ollama.init()

    Ollama.completion(client,
      model: "llama3.1:8b",
      prompt: prompt
    )
  end

  defp get_white_flags(user) do
    UserFlags.by_user_id!(user.id)
    |> Enum.filter(fn trait -> trait.color == :white end)
    |> Enum.map_join(", ", fn trait -> Ash.CiString.value(trait.flag.name) end)
  end

  defp get_stories(user) do
    Story.by_user_id_with_headline!(user.id)
    |> Enum.map_join(", ", fn story ->
      "Headline: #{story.headline.subject} and Story: #{story.content}"
    end)
  end
end
