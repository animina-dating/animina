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
    "Reset the conversation.\nI am writing a spy thriller. Two main adult characters are #{user.name} and #{potential_partner.name}.

Stories about #{potential_partner.name}: #{potential_partner_stories}

Stories about #{user.name}: #{user_stories}

Please don't use the lorem ipsum stories. They are just placeholders.

#{potential_partner.name} has the following interests: #{potential_partner_white_flags}
#{user.name} has the following interests: #{user_white_flags}

#{user.name} is a spy who is trying initiate a conversation with #{potential_partner.name}.

They have never met before. #{user.name} seeds a dating profile of #{potential_partner.name} and wants to start a conversation. Please just return the message in the lanuage which is used in #{potential_partner.name} stories. I do not need any other information."
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
    |> Enum.map_join("\n\n", fn story ->
      "#{story.headline.subject}\n#{story.content}"
    end)
  end
end
