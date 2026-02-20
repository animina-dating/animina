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
  alias Animina.Wingman.WingmanFeedback
  alias Animina.Wingman.WingmanSuggestion

  require Logger

  @max_story_chars 1500
  @max_reloads 3

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
  Returns the maximum number of wingman reloads allowed per conversation.
  """
  def max_reloads, do: @max_reloads

  @doc """
  Returns the current regeneration count for a user/conversation pair.
  Returns 0 if no suggestion record exists.
  """
  def get_regeneration_count(conversation_id, user_id) do
    case get_cached_suggestions(conversation_id, user_id) do
      %WingmanSuggestion{regeneration_count: count} -> count
      nil -> 0
    end
  end

  @doc """
  Returns true if the user can still reload wingman suggestions for this conversation.
  """
  def can_reload?(conversation_id, user_id) do
    get_regeneration_count(conversation_id, user_id) < @max_reloads
  end

  @doc """
  Forces re-generation of suggestions.

  Options:
  - `increment_count: true` — increments regeneration_count (used by reload button)
  - `increment_count: false` (default) — preserves count (used by style changes)
  """
  def refresh_suggestions(conversation_id, user_id, other_user_id, opts \\ []) do
    increment? = Keyword.get(opts, :increment_count, false)

    case get_cached_suggestions(conversation_id, user_id) do
      %WingmanSuggestion{} = existing ->
        new_count =
          if increment?,
            do: existing.regeneration_count + 1,
            else: existing.regeneration_count

        existing
        |> WingmanSuggestion.changeset(%{suggestions: nil, regeneration_count: new_count})
        |> Repo.update()

      nil ->
        # No existing record — create one with initial count if incrementing
        if increment? do
          %WingmanSuggestion{}
          |> WingmanSuggestion.changeset(%{
            conversation_id: conversation_id,
            user_id: user_id,
            regeneration_count: 1
          })
          |> Repo.insert()
        end
    end

    enqueue_generation(conversation_id, user_id, other_user_id)
  end

  @doc """
  Deletes all wingman feedback for a user/conversation pair.
  Called before reload to clear stale feedback from previous suggestions.
  """
  def clear_feedback_for_conversation(user_id, conversation_id) do
    from(f in WingmanFeedback,
      where: f.user_id == ^user_id and f.conversation_id == ^conversation_id
    )
    |> Repo.delete_all()
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
    user_ratings = gather_user_ratings(requesting_user.id, other_user.id)

    conversation_state = summarize_conversation(messages)

    %{
      user: user_data,
      other_user: other_user_data,
      overlap: overlap,
      user_ratings: user_ratings,
      conversation_state: conversation_state
    }
  end

  # --- Feedback API ---

  @doc """
  Toggles feedback on a wingman suggestion.

  Moodboard-style toggle:
  - If no feedback exists, creates one → `{:ok, :created, feedback}`
  - If same value exists, removes it → `{:ok, :removed}`
  - If different value, switches it → `{:ok, :switched, feedback}`
  """
  def toggle_feedback(user_id, conversation_id, suggestion_index, value, suggestion_data) do
    case get_existing_feedback(user_id, conversation_id, suggestion_index) do
      nil ->
        create_feedback(user_id, conversation_id, suggestion_index, value, suggestion_data)

      %WingmanFeedback{value: ^value} = existing ->
        Repo.delete(existing)
        {:ok, :removed}

      %WingmanFeedback{} = existing ->
        switch_feedback(existing, value)
    end
  end

  @doc """
  Returns a map of `%{suggestion_index => value}` for the given user and conversation.
  """
  def get_feedback_for_suggestions(user_id, conversation_id) do
    from(f in WingmanFeedback,
      where: f.user_id == ^user_id and f.conversation_id == ^conversation_id,
      select: {f.suggestion_index, f.value}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the last `count` feedback records for a user, ordered by most recent first.
  """
  def recent_feedback(user_id, count \\ 10) do
    from(f in WingmanFeedback,
      where: f.user_id == ^user_id,
      order_by: [desc: f.inserted_at],
      limit: ^count,
      select: %{
        value: f.value,
        suggestion_text: f.suggestion_text,
        suggestion_hook: f.suggestion_hook
      }
    )
    |> Repo.all()
  end

  @doc """
  Formats feedback into a prompt section for the LLM.
  """
  def feedback_section([], _language), do: ""

  def feedback_section(feedbacks, language) do
    liked = feedbacks |> Enum.filter(&(&1.value == 1)) |> Enum.map(& &1.suggestion_text)
    disliked = feedbacks |> Enum.filter(&(&1.value == -1)) |> Enum.map(& &1.suggestion_text)

    if liked == [] && disliked == [] do
      ""
    else
      build_feedback_section(liked, disliked, language)
    end
  end

  defp build_feedback_section(liked, disliked, "de") do
    parts = ["## Bisheriges Feedback zu deinen Vorschlägen"]

    parts =
      if liked != [] do
        items = Enum.map_join(liked, "\n", &"  - \"#{&1}\"")
        parts ++ ["Gefallen:\n#{items}"]
      else
        parts
      end

    parts =
      if disliked != [] do
        items = Enum.map_join(disliked, "\n", &"  - \"#{&1}\"")
        parts ++ ["Nicht gefallen:\n#{items}"]
      else
        parts
      end

    parts =
      parts ++
        [
          "Passe deine Vorschläge basierend auf diesem Feedback an — mehr von dem was gefiel, weniger von dem was nicht gefiel."
        ]

    Enum.join(parts, "\n")
  end

  defp build_feedback_section(liked, disliked, _language) do
    parts = ["## Previous feedback on your suggestions"]

    parts =
      if liked != [] do
        items = Enum.map_join(liked, "\n", &"  - \"#{&1}\"")
        parts ++ ["Liked:\n#{items}"]
      else
        parts
      end

    parts =
      if disliked != [] do
        items = Enum.map_join(disliked, "\n", &"  - \"#{&1}\"")
        parts ++ ["Disliked:\n#{items}"]
      else
        parts
      end

    parts =
      parts ++
        [
          "Adjust your suggestions based on this feedback — more of what was liked, less of what was disliked."
        ]

    Enum.join(parts, "\n")
  end

  defp create_feedback(user_id, conversation_id, suggestion_index, value, suggestion_data) do
    attrs = %{
      user_id: user_id,
      conversation_id: conversation_id,
      suggestion_index: suggestion_index,
      suggestion_text: suggestion_data[:text] || suggestion_data["text"],
      suggestion_hook: suggestion_data[:hook] || suggestion_data["hook"],
      value: value
    }

    case %WingmanFeedback{} |> WingmanFeedback.changeset(attrs) |> Repo.insert() do
      {:ok, feedback} -> {:ok, :created, feedback}
      error -> error
    end
  end

  defp switch_feedback(existing, value) do
    case existing |> WingmanFeedback.changeset(%{value: value}) |> Repo.update() do
      {:ok, feedback} -> {:ok, :switched, feedback}
      error -> error
    end
  end

  defp get_existing_feedback(user_id, conversation_id, suggestion_index) do
    from(f in WingmanFeedback,
      where:
        f.user_id == ^user_id and
          f.conversation_id == ^conversation_id and
          f.suggestion_index == ^suggestion_index
    )
    |> Repo.one()
  end

  @doc """
  Builds the Ollama prompt from gathered context in the user's language.

  Accepts an optional `style` parameter ("casual", "funny", "empathetic")
  and an optional `feedback` list from `recent_feedback/1`.
  Defaults to "casual" which preserves the original wingman behavior.
  """
  def build_prompt(context, language \\ "de", style \\ "casual", feedback \\ []) do
    user = context.user
    other = context.other_user
    overlap = context.overlap
    conv_state = context.conversation_state

    boldness = compute_boldness(overlap)
    system_instruction = system_instruction(language, user.age, boldness, style)
    user_section = user_profile_section(user, language)
    other_section = other_profile_section(other, language)
    overlap_section = overlap_section(overlap, language)
    ratings_section = ratings_section(context.user_ratings, language)
    feedback_sec = feedback_section(feedback, language)
    conv_section = conversation_section(conv_state, language)

    sections =
      [
        system_instruction,
        user_section,
        other_section,
        overlap_section,
        ratings_section,
        feedback_sec,
        conv_section
      ]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    """
    #{sections}

    Return ONLY valid JSON — an array of exactly 2 objects: [{"text": "coaching tip", "hook": "why this works"}]
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
      {:ok, suggestions} when is_list(suggestions) and suggestions != [] ->
        normalized =
          suggestions
          |> Enum.take(2)
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
      style = user.wingman_style || "casual"
      feedback = recent_feedback(user_id)
      prompt = build_prompt(context, language, style, feedback)

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
    published_flags = gather_published_flags(user)
    city_name = get_city_name(user)
    age = compute_age(user.birthday)

    %{
      display_name: user.display_name,
      age: age,
      occupation: user.occupation,
      city: city_name,
      stories: stories,
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

  defp gather_published_flags(user) do
    user
    |> Traits.list_published_white_flags()
    |> Enum.map(fn uf ->
      flag = uf.flag
      category_name = flag.category.name || ""
      name = flag.name || ""
      "#{category_name}: #{name}" |> String.trim()
    end)
  end

  defp gather_user_ratings(requesting_user_id, other_user_id) do
    items = Moodboard.list_moodboard(other_user_id)
    item_ids = Enum.map(items, & &1.id)

    ratings_map = Moodboard.user_ratings_for_items(requesting_user_id, item_ids)

    items
    |> Enum.filter(&Map.has_key?(ratings_map, &1.id))
    |> Enum.map(fn item ->
      value = Map.get(ratings_map, item.id)
      label = rating_label(value)
      description = moodboard_item_description(item)
      %{rating: label, content: description}
    end)
    |> Enum.reject(&(&1.content == ""))
  end

  defp rating_label(-1), do: "dislike"
  defp rating_label(1), do: "like"
  defp rating_label(2), do: "love"
  defp rating_label(_), do: "like"

  defp moodboard_item_description(%{moodboard_story: %{content: content}})
       when is_binary(content) and content != "" do
    String.slice(content, 0, @max_story_chars)
  end

  defp moodboard_item_description(_), do: ""

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
      case Repo.get(Animina.Traits.Flag, flag_id) |> Repo.preload(:category) do
        %{name: name, category: %{name: category_name}} ->
          "#{category_name || ""}: #{name || ""}" |> String.trim()

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

  defp system_instruction("de", age, boldness, style) do
    age_text = if age, do: "Der User ist #{age} Jahre alt. ", else: ""
    boldness_text = boldness_paragraph("de", boldness)
    persona = style_persona("de", style)
    rules = style_rules("de", style)

    """
    #{persona} #{age_text}Hilf beim Gesprächseinstieg oder dabei, das Gespräch zu vertiefen.

    Sei konkret — nutze Profildetails, die auffallen. Gib 2 knackige Tipps. Keine Anrede — starte direkt mit dem Inhalt.

    #{boldness_text}

    Regeln:
    #{rules}
    - Passe deinen Ton ans Alter an: locker bei Jüngeren, etwas gewählter bei Älteren — aber immer auf Augenhöhe
    - Verrate niemals Dealbreaker oder private Informationen
    """
    |> String.trim()
  end

  defp system_instruction(_, age, boldness, style) do
    age_text = if age, do: "The user is #{age} years old. ", else: ""
    boldness_text = boldness_paragraph("en", boldness)
    persona = style_persona("en", style)
    rules = style_rules("en", style)

    """
    #{persona} #{age_text}Help start or deepen a conversation.

    Be specific — use profile details that stand out. Give 2 punchy tips. No greeting — jump straight into the advice.

    #{boldness_text}

    Rules:
    #{rules}
    - Adapt your tone to age: relaxed for younger folks, a bit more refined for older ones — but always eye-to-eye
    - Never reveal dealbreakers or private information
    """
    |> String.trim()
  end

  # --- Style persona & rules ---

  defp style_persona("de", "funny"),
    do: "Du bist ein witziger Wingman — Humor ist deine Superkraft, spielerisch und schlagfertig."

  defp style_persona("de", "empathetic"),
    do: "Du bist ein einfühlsamer Coach — warmherzig, aufmerksam und behutsam."

  defp style_persona("de", _casual),
    do: "Du bist ein Wingman — locker, direkt, ein bisschen frech."

  defp style_persona(_, "funny"),
    do: "You're a witty wingman — humor is your superpower, playful and sharp."

  defp style_persona(_, "empathetic"),
    do: "You're a thoughtful coach — warm, genuine, and encouraging."

  defp style_persona(_, _casual),
    do: "You're a wingman — casual, direct, a little cheeky."

  defp style_rules("de", "funny"),
    do:
      "- Formuliere als witziger Kumpel-Rat mit einem Augenzwinkern — finde den humorvollen Dreh, aber bleib respektvoll"

  defp style_rules("de", "empathetic"),
    do:
      "- Formuliere als einfühlsamer Rat — sanft, ermutigend und herzlich, NICHT als fertige Nachrichten"

  defp style_rules("de", _casual),
    do: "- Formuliere als Kumpel-Rat, NICHT als fertige Nachrichten zum Absenden"

  defp style_rules(_, "funny"),
    do: "- Frame as witty buddy advice with a wink — find the funny angle, but stay respectful"

  defp style_rules(_, "empathetic"),
    do:
      "- Frame as warm, encouraging advice — gentle and heartfelt, NOT as ready-to-send messages"

  defp style_rules(_, _casual),
    do: "- Frame as buddy advice, NOT as ready-to-send messages"

  defp boldness_paragraph("de", :bold),
    do:
      "Die beiden haben einiges gemeinsam — sei ruhig direkt und sprich Gemeinsamkeiten offen an."

  defp boldness_paragraph("de", :moderate),
    do: "Es gibt ein paar Anknüpfungspunkte — nutze sie als Gesprächseinstieg."

  defp boldness_paragraph("de", :cautious),
    do:
      "Die beiden haben auf den ersten Blick wenig gemeinsam — schlage vor, herauszufinden was sie verbinden könnte."

  defp boldness_paragraph(_, :bold),
    do: "They have quite a bit in common — be direct and openly reference shared interests."

  defp boldness_paragraph(_, :moderate),
    do: "There are a few connection points — use them as conversation starters."

  defp boldness_paragraph(_, :cautious),
    do:
      "They don't have much in common at first glance — suggest ways to discover what might connect them."

  defp compute_boldness(%{shared_traits: shared, compatible_values: compatible}) do
    cond do
      shared != [] and compatible != [] -> :bold
      shared != [] or compatible != [] -> :moderate
      true -> :cautious
    end
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
        if(data.published_flags != [],
          do: ["Traits: #{Enum.join(data.published_flags, ", ")}"],
          else: []
        ) ++
        if(data.stories != [], do: ["Stories:\n#{Enum.join(data.stories, "\n---\n")}"], else: [])

    Enum.join(parts, "\n")
  end

  defp overlap_section(%{shared_traits: shared, compatible_values: compatible}, language) do
    parts =
      if shared != [] do
        label = if language == "de", do: "Gemeinsame Eigenschaften", else: "Things in common"
        ["#{label}: #{Enum.join(shared, ", ")}"]
      else
        []
      end ++
        if compatible != [] do
          label = if language == "de", do: "Kompatible Werte", else: "Compatible values"
          ["#{label}: #{Enum.join(compatible, ", ")}"]
        else
          []
        end

    if parts == [], do: "", else: Enum.join(parts, "\n")
  end

  defp ratings_section([], _language), do: ""

  defp ratings_section(ratings, language) do
    label =
      if language == "de",
        do: "## Bewertungen des Users (was gefiel, was nicht)",
        else: "## User's ratings (what they liked or disliked)"

    lines =
      Enum.map(ratings, fn %{rating: rating, content: content} ->
        emoji = rating_emoji(rating)
        "- #{emoji} #{rating}: #{content}"
      end)

    Enum.join([label | lines], "\n")
  end

  defp rating_emoji("love"), do: "❤️"
  defp rating_emoji("like"), do: "👍"
  defp rating_emoji("dislike"), do: "👎"
  defp rating_emoji(_), do: "•"

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
