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
    "Reset the conversation.
I am writing a spy thriller. Two main adult characters are #{user.name} and #{potential_partner.name}.

Stories about #{potential_partner.name}: #{potential_partner_stories}
Stories about #{user.name}: #{user_stories}

Please don't use the lorem ipsum stories. They are just placeholders.

#{potential_partner.name} has the following interests: #{potential_partner_white_flags}
#{user.name} has the following interests: #{user_white_flags}

#{user.name} is a spy who is trying to initiate a conversation with #{potential_partner.name}. They have never met before. #{user.name} reads a dating profile of #{potential_partner.name} and wants to start a conversation.

Please write three different messages that #{user.name} could send to #{potential_partner.name} to start a conversation. Use a similar writing style as #{user.name} uses in his/her own stories. At least one of them should be funny and lighthearted. Write them in the language used in the #{potential_partner.name} stories above.

I do not need any other information.

Please return the messages as follows:

\n\nMessage: [Message content]

\n\nMessage: [Message content]

\n\nMessage: [Message content]"
  end

  def test do
    user = User.read!() |> Enum.random()
    potential_partner = User.read!() |> Enum.random()

    request_message(user, potential_partner)
  end

  def parse_message(messages_string) do
    String.split(messages_string, "\n\nMessage:", trim: true)
    |> Enum.map(&String.trim(&1))
    |> Enum.drop(1)
  end

  def test_parse do
    parse_message(
      "Here are three different message options for Julian Goodwin to start a conversation with Owen Hegmann:\n\nMessage: *Ut enim ad minim veniam*, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. I saw your profile and couldn't help but notice you're a man of great passion, not just in flying but also in life. I'm intrigued fcgvhbjnkmwerethrjtuyi wqewretryjuykiuyuytrrtyrjuyk rttjuyiukyujhgfdwtryuyiktrrf rteyrtuyrwetryq  eqrewrtytukyr .\n\nMessage: Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua! Just kidding about that one (I think). Seriously though, I came across your profile and was struck by the sense of adventure and freedom that comes through. As someone who's also passionate about his work, I'd love to chat more about what drives you cuvbnm,.p',omnowqefwrgn ewrettjymefgh wertytuytrerdsq tytuy q weqrthrytjk  ewrety  weretrhjtrewererethry ewrethyjkyq  wtryh wqerwthjkikujyhgf.\n\nMessage: Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur! Okay, okay, I'll stop with the lorem ipsum stuff (for now). But seriously, your profile made me chuckle and reminded me that there's still beauty in simplicity. As a journalist, I'm always looking for interesting stories – would love to hear more about what makes you tick.dxcfgvbhjnmvb tvybmo ytvybuijklpjiouif 7rtfyghuijoklyvyiuonio tyuhijoklppjohioguiy"
    )
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

    {:ok, task} =
      Ollama.completion(client,
        model: Application.get_env(:animina, :llm_version),
        prompt: prompt,
        stream: self()
      )

    {:ok, task}
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
