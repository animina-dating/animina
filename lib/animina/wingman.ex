defmodule Animina.Wingman do
  @moduledoc """
  Context for AI-powered conversation coaching ("Wingman").

  Generates personalized conversation tips using publicly visible profile data.
  Uses the Ollama AI queue for async generation.

  ## Privacy Rules

  - Uses freely: moodboard stories, photo descriptions, published white flags,
    occupation, city, age
  - Uses delicately: green flags (framed as shared values), white_white and
    green_white overlap
  - Never uses: private/unpublished white flags, red flags, red_white conflicts,
    sensitive categories without mutual opt-in
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.AI
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Moodboard
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Traits
  alias Animina.Traits.Matching
  alias Animina.Wingman.WingmanSuggestion

  require Logger

  @max_story_chars 500
  @max_photo_desc_chars 200

  # --- PubSub ---

  def suggestion_topic(conversation_id, user_id) do
    "wingman:#{conversation_id}:#{user_id}"
  end

  # --- Public API ---

  @doc """
  Returns existing suggestions or triggers async generation.

  Returns:
  - `{:ok, suggestions}` — cached suggestions available
  - `{:pending, job_id}` — generation in progress
  - `{:error, reason}` — something went wrong
  """
  def get_or_generate_suggestions(conversation_id, user_id, other_user_id) do
    case get_cached_suggestions(conversation_id, user_id) do
      %WingmanSuggestion{suggestions: suggestions} when is_list(suggestions) ->
        {:ok, suggestions}

      _ ->
        enqueue_generation(conversation_id, user_id, other_user_id)
    end
  end

  @doc """
  Forces re-generation of suggestions.
  """
  def refresh_suggestions(conversation_id, user_id, other_user_id) do
    # Delete existing suggestions first
    from(ws in WingmanSuggestion,
      where: ws.conversation_id == ^conversation_id and ws.user_id == ^user_id
    )
    |> Repo.delete_all()

    enqueue_generation(conversation_id, user_id, other_user_id)
  end

  @doc """
  Deletes cached suggestions for a conversation/user pair.
  Called after the first message is sent.
  """
  def delete_suggestions(conversation_id, user_id) do
    from(ws in WingmanSuggestion,
      where: ws.conversation_id == ^conversation_id and ws.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Assembles safe-to-use profile data for both users.

  Returns a map with `:user`, `:other_user`, `:overlap`, and `:conversation_state`.
  """
  def gather_context(requesting_user, other_user, messages) do
    user_data = gather_user_data(requesting_user)
    other_user_data = gather_user_data(other_user)

    overlap = gather_safe_overlap(requesting_user, other_user)

    conversation_state = summarize_conversation(messages)

    %{
      user: user_data,
      other_user: other_user_data,
      overlap: overlap,
      conversation_state: conversation_state
    }
  end

  @doc """
  Builds the Ollama prompt from gathered context in the user's language.
  """
  def build_prompt(context, language \\ "de") do
    user = context.user
    other = context.other_user
    overlap = context.overlap
    conv_state = context.conversation_state

    system_instruction = system_instruction(language)
    user_section = user_profile_section(user, language)
    other_section = other_profile_section(other, language)
    overlap_section = overlap_section(overlap, language)
    conv_section = conversation_section(conv_state, language)

    """
    #{system_instruction}

    #{user_section}

    #{other_section}

    #{overlap_section}

    #{conv_section}

    Return ONLY valid JSON — an array of exactly 3 objects: [{"text": "coaching tip", "hook": "why this works"}]
    No markdown, no explanation, just the JSON array.
    """
  end

  @doc """
  Parses the raw LLM response into structured suggestions.

  Returns `{:ok, suggestions}` or `{:error, :parse_failed}`.
  """
  def parse_suggestions(nil), do: {:error, :parse_failed}
  def parse_suggestions(""), do: {:error, :parse_failed}

  def parse_suggestions(raw_response) do
    # Try to extract JSON array from response
    case extract_json_array(raw_response) do
      {:ok, suggestions} when is_list(suggestions) and length(suggestions) > 0 ->
        normalized =
          suggestions
          |> Enum.take(3)
          |> Enum.map(fn item ->
            %{
              "text" => to_string(Map.get(item, "text", "")),
              "hook" => to_string(Map.get(item, "hook", ""))
            }
          end)
          |> Enum.filter(fn %{"text" => text} -> text != "" end)

        if Enum.empty?(normalized),
          do: {:error, :parse_failed},
          else: {:ok, normalized}

      _ ->
        {:error, :parse_failed}
    end
  end

  @doc """
  Saves suggestions to the database and broadcasts via PubSub.
  """
  def save_and_broadcast(conversation_id, user_id, suggestions, context_hash, ai_job_id) do
    attrs = %{
      conversation_id: conversation_id,
      user_id: user_id,
      suggestions: suggestions,
      context_hash: context_hash,
      ai_job_id: ai_job_id
    }

    result =
      case get_cached_suggestions(conversation_id, user_id) do
        nil ->
          %WingmanSuggestion{}
          |> WingmanSuggestion.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> WingmanSuggestion.changeset(attrs)
          |> Repo.update()
      end

    case result do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(
          Animina.PubSub,
          suggestion_topic(conversation_id, user_id),
          {:wingman_ready, suggestions}
        )

        {:ok, suggestions}

      error ->
        error
    end
  end

  @doc """
  Computes a hash of the context data for staleness detection.
  """
  def context_hash(context) do
    context
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  # --- Private ---

  defp get_cached_suggestions(conversation_id, user_id) do
    from(ws in WingmanSuggestion,
      where: ws.conversation_id == ^conversation_id and ws.user_id == ^user_id
    )
    |> Repo.one()
  end

  defp enqueue_generation(conversation_id, user_id, other_user_id) do
    user = Accounts.get_user(user_id)
    other_user = Accounts.get_user(other_user_id)

    if is_nil(user) or is_nil(other_user) do
      {:error, :user_not_found}
    else
      messages = Messaging.list_messages(conversation_id, user_id)
      context = gather_context(user, other_user, messages)
      hash = context_hash(context)
      language = user.language || "de"
      prompt = build_prompt(context, language)

      params = %{
        "conversation_id" => conversation_id,
        "user_id" => user_id,
        "other_user_id" => other_user_id,
        "prompt" => prompt,
        "context_hash" => hash
      }

      case AI.enqueue("wingman_suggestion", params, requester_id: user_id) do
        {:ok, job} -> {:pending, job.id}
        error -> error
      end
    end
  end

  defp gather_user_data(user) do
    # Reload user with locations
    user = Repo.preload(user, :locations)

    stories = gather_stories(user.id)
    photo_descriptions = gather_photo_descriptions(user.id)
    published_flags = gather_published_flags(user)
    city_name = get_city_name(user)
    age = compute_age(user.birthday)

    %{
      display_name: user.display_name,
      age: age,
      occupation: user.occupation,
      city: city_name,
      stories: stories,
      photo_descriptions: photo_descriptions,
      published_flags: published_flags
    }
  end

  defp gather_stories(user_id) do
    user_id
    |> Moodboard.list_moodboard()
    |> Enum.flat_map(fn item ->
      case item.moodboard_story do
        %{content: content} when is_binary(content) and content != "" ->
          [String.slice(content, 0, @max_story_chars)]

        _ ->
          []
      end
    end)
  end

  defp gather_photo_descriptions(user_id) do
    user_id
    |> Moodboard.list_moodboard()
    |> Enum.flat_map(fn item ->
      case item.moodboard_photo do
        %{photo: %{description: desc}} when is_binary(desc) and desc != "" ->
          [String.slice(desc, 0, @max_photo_desc_chars)]

        _ ->
          []
      end
    end)
  end

  defp gather_published_flags(user) do
    user
    |> Traits.list_published_white_flags()
    |> Enum.map(fn uf ->
      flag = uf.flag
      emoji = flag.emoji || ""
      name = flag.name || ""
      "#{emoji} #{name}" |> String.trim()
    end)
  end

  defp gather_safe_overlap(user_a, user_b) do
    overlap = Matching.compute_flag_overlap(user_a, user_b)

    white_white_names = resolve_flag_names(overlap.white_white)
    green_white_names = resolve_flag_names(overlap.green_white)

    %{
      shared_traits: white_white_names,
      compatible_values: green_white_names
    }
  end

  defp resolve_flag_names(flag_ids) do
    flag_ids
    |> Enum.map(fn flag_id ->
      case Repo.get(Animina.Traits.Flag, flag_id) do
        %{name: name, emoji: emoji} ->
          "#{emoji || ""} #{name || ""}" |> String.trim()

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_city_name(%{locations: [first_location | _]}) do
    case GeoData.get_city_by_zip_code(first_location.zip_code) do
      %{name: name} -> name
      _ -> nil
    end
  end

  defp get_city_name(_), do: nil

  defp compute_age(nil), do: nil

  defp compute_age(birthday) do
    today = TimeMachine.utc_today()
    years = Date.diff(today, birthday) |> div(365)
    years
  end

  defp summarize_conversation(messages) do
    count = length(messages)

    cond do
      count == 0 -> "new"
      count <= 5 -> "early (#{count} messages)"
      true -> "ongoing (#{count} messages)"
    end
  end

  # --- Prompt building ---

  defp system_instruction("de") do
    """
    Du bist ein warmherziger, einfühlsamer Dating-Coach. Gib 3 kurze Coaching-Tipps \
    um ein Gespräch zu beginnen oder zu vertiefen. Sei konkret — beziehe dich auf \
    Profildetails. Verrate niemals Dealbreaker oder private Informationen. \
    Formuliere als freundschaftlicher Rat, NICHT als fertige Nachrichten zum Absenden.
    """
    |> String.trim()
  end

  defp system_instruction(_) do
    """
    You are a warm, thoughtful dating coach. Give 3 short coaching tips \
    for starting or deepening a conversation. Be specific — reference profile details. \
    Never reveal dealbreakers or private information. \
    Frame as friendly advice, NOT as ready-to-send messages.
    """
    |> String.trim()
  end

  defp user_profile_section(user, language) do
    label = if language == "de", do: "Über dich", else: "About you"
    format_profile_section(label, user.display_name, user)
  end

  defp other_profile_section(other, language) do
    label = if language == "de", do: "Über", else: "About"
    format_profile_section("#{label} #{other.display_name}", other.display_name, other)
  end

  defp format_profile_section(label, _name, data) do
    parts =
      ["## #{label}"] ++
        if(data.age, do: ["Age: #{data.age}"], else: []) ++
        if(data.city, do: ["City: #{data.city}"], else: []) ++
        if(data.occupation, do: ["Occupation: #{data.occupation}"], else: []) ++
        if(data.published_flags != [], do: ["Traits: #{Enum.join(data.published_flags, ", ")}"], else: []) ++
        if(data.stories != [], do: ["Stories:\n#{Enum.join(data.stories, "\n---\n")}"], else: []) ++
        if(data.photo_descriptions != [], do: ["Photo descriptions: #{Enum.join(data.photo_descriptions, "; ")}"], else: [])

    Enum.join(parts, "\n")
  end

  defp overlap_section(%{shared_traits: shared, compatible_values: compatible}, language) do
    parts =
      if(shared != []) do
        label = if language == "de", do: "Gemeinsame Eigenschaften", else: "Things in common"
        ["#{label}: #{Enum.join(shared, ", ")}"]
      else
        []
      end ++
        if(compatible != []) do
          label = if language == "de", do: "Kompatible Werte", else: "Compatible values"
          ["#{label}: #{Enum.join(compatible, ", ")}"]
        else
          []
        end

    if parts == [], do: "", else: Enum.join(parts, "\n")
  end

  defp conversation_section(state, language) do
    label = if language == "de", do: "Gesprächsstatus", else: "Conversation state"
    "#{label}: #{state}"
  end

  # --- JSON extraction ---

  defp extract_json_array(text) do
    # Find JSON array in the response
    case Regex.run(~r/\[[\s\S]*?\]/s, text) do
      [json_str] ->
        case Jason.decode(json_str) do
          {:ok, list} when is_list(list) -> {:ok, list}
          _ -> :error
        end

      nil ->
        :error
    end
  end
end
