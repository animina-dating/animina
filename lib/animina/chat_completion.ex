defmodule Animina.ChatCompletion do
  @moduledoc """
  This module is responsible for generating a chat message for a dating app.
  """
  alias Animina.Accounts.User
  alias Animina.Narratives.Story
  alias Animina.Traits.UserFlags

  def chat_prompt(
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

#{potential_partner.name} has the following interests: #{potential_partner_white_flags}
#{user.name} has the following interests: #{user_white_flags}

#{user.name} is a spy who is trying to initiate a conversation with #{potential_partner.name}. They have never met before. #{user.name} reads a dating profile of #{potential_partner.name} and wants to start a conversation.

Please write three different messages that #{user.name} could send to #{potential_partner.name} to start a conversation in a chatroom. One message should be open and flirty, the second one lighthearted and funny and the last one the same way the stories are writen. Use a similar writing style as #{user.name} uses in his or her own stories. Add markdown and emojis when it makes sense. Write them in the language used in the #{potential_partner.name} stories above.

I do not need any other information.

Please return the messages as follows:

Do not use square brackets [] or \" around the messages.

Make sure to always return three messages.

\n\nMessage: [Message content]

\n\nMessage: [Message content]

\n\nMessage: [Message content]"
  end

  def stories_prompt(headline, content, reasons, previous) do
    _writing_style = """
    Steps:
    1. Generate a short assessment of the #{previous} stories on all the key writing style elements defined below. Be definitive:
    • Diction (word choice): Vocabulary, Formality, Connotation
    • Syntax (sentence structure): Length, Variety, Complexity
    • Tone: Attitude, Mood, Voice
    • Figurative Language: Metaphors and Similes, Symbolism, Irony
    • Structure: Organization, Transitions, Pacing
    • Rhetorical Devices: Repetition, Alliteration, Rhetorical Questions
    • Authorial Intent and Purpose: Persuasion, Information, Entertainment
    """

    _vocab_list = """
    Steps:
    1. Based on the #{previous} stories, generate a comprehensive overview of the writer's vocabulary and style elements.
    2. Build a vocabulary list of the most common superlatives, adjectives, adverbs, vocal fry (in a writing sense), emphasis words, transitional phrases, rhetorical devices, idioms and colloquialisms, etc. Make a massive list.
    """

    prompt = """
    You are a skilled language model trained to rewrite and improve user-generated stories based on the provided writing style and vocabulary list. Your task is to help users create engaging stories while keeping the content concise.

    Below is the user's selected headline, their original story content, and reasons they want improvements:

    Headline: #{headline}
    Content: #{content}

    Reasons for Improvement: #{reasons}

    ### Instructions:
    1. **Maintain Style**: Follow the original story's tone, style, and vocabulary.
    2. **Preserve Meaning**: Keep the original intent and key details intact. Do not introduce new ideas or remove essential elements.
    3. **Apply Adjustments**: Make improvements based on the user's reasons:
    - Fix grammatical, spelling, and punctuation errors.
    - Add humor or excitement as requested, while staying appropriate.
    - Condense or expand content as specified without changing the core message.
    4. **Consistency**: Ensure the story reads smoothly and has no redundancies.

    ### Output Constraints:
    - The revised story must be **at least 50 characters** and **no more than 1024 characters**, including spaces.
    - Return **only the revised story content**.
    - Do not include any introductory text, explanations, or extra phrases like "This is the updated story."
    - **Strictly limit the response to 1024 characters maximum**, including spaces.

    ### Generate Output:
    Return only the revised story content, ensuring it does not exceed 1024 characters.

    """

    prompt
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
      chat_prompt(
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

  def request_stories(headline, content, reason, previous) do
    prompt = stories_prompt(headline, content, reason, previous)

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
