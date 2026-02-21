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
  alias Animina.Discovery.Filters.FilterHelpers
  alias Animina.Discovery.Schemas.SpotlightEntry
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
    requesting_user = Repo.preload(requesting_user, :locations)
    other_user = Repo.preload(other_user, :locations)

    user_data = gather_user_data(requesting_user)
    other_user_data = gather_user_data(other_user)

    overlap = gather_safe_overlap(requesting_user, other_user)
    user_ratings = gather_user_ratings(requesting_user.id, other_user.id)
    distance_km = compute_distance(requesting_user, other_user)
    is_wildcard = wildcard?(requesting_user.id, other_user.id)

    conversation_state = summarize_conversation(messages)

    %{
      user: user_data,
      other_user: other_user_data,
      overlap: overlap,
      user_ratings: user_ratings,
      distance_km: distance_km,
      is_wildcard: is_wildcard,
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
  """
  def build_prompt(context, language \\ "de") do
    user = context.user
    other = context.other_user
    overlap = context.overlap
    conv_state = context.conversation_state

    is_wildcard = Map.get(context, :is_wildcard, false)
    boldness = compute_boldness(overlap)

    system_instruction =
      system_instruction(language, user.age, boldness, other.gender, other.display_name)

    time_section = time_context_section(language)
    user_section = user_profile_section(user, language)
    other_section = other_profile_section(other, language)
    overlap_section = overlap_section(overlap, context.distance_km, language)
    wildcard_section = wildcard_section(is_wildcard, language)
    ratings_section = ratings_section(context.user_ratings, language)
    conv_section = conversation_section(conv_state, language)

    sections =
      [
        system_instruction,
        time_section,
        user_section,
        other_section,
        overlap_section,
        wildcard_section,
        ratings_section,
        conv_section
      ]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    json_instruction = json_instruction(language)

    """
    #{sections}

    #{json_instruction}
    """
  end

  @doc """
  Parses the raw LLM response into structured suggestions.

  Returns `{:ok, suggestions}` or `{:error, :parse_failed}`.
  """
  def parse_suggestions(nil), do: {:error, :parse_failed}
  def parse_suggestions(""), do: {:error, :parse_failed}

  def parse_suggestions(raw_response) do
    if repetitive?(raw_response) do
      {:error, :parse_failed}
    else
      raw_response
      |> extract_json_array()
      |> normalize_suggestions()
    end
  end

  defp normalize_suggestions({:ok, suggestions})
       when is_list(suggestions) and suggestions != [] do
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
  end

  defp normalize_suggestions(_), do: {:error, :parse_failed}

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
    published_flags = gather_published_flags(user)
    city_name = get_city_name(user)
    age = compute_age(user.birthday)

    %{
      display_name: user.display_name,
      age: age,
      gender: user.gender,
      height: user.height,
      occupation: user.occupation,
      city: city_name,
      search_radius: user.search_radius,
      partner_age_min: if(user.birthday, do: age - user.partner_minimum_age_offset),
      partner_age_max: if(user.birthday, do: age + user.partner_maximum_age_offset),
      partner_height_min: user.partner_height_min,
      partner_height_max: user.partner_height_max,
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

  defp resolve_flag_names([]), do: []

  defp resolve_flag_names(flag_ids) do
    flags =
      from(f in Animina.Traits.Flag,
        where: f.id in ^flag_ids,
        preload: [:category]
      )
      |> Repo.all()

    Enum.map(flags, fn
      %{name: name, category: %{name: category_name}} ->
        "#{category_name || ""}: #{name || ""}" |> String.trim()

      _ ->
        nil
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

  defp wildcard?(viewer_id, shown_user_id) do
    today = TimeMachine.utc_today()

    from(e in SpotlightEntry,
      where:
        e.user_id == ^viewer_id and
          e.shown_user_id == ^shown_user_id and
          e.shown_on == ^today and
          e.is_wildcard == true
    )
    |> Repo.exists?()
  end

  defp compute_distance(user_a, user_b) do
    with {:ok, lat1, lon1} <- FilterHelpers.get_viewer_coordinates(user_a),
         {:ok, lat2, lon2} <- FilterHelpers.get_viewer_coordinates(user_b) do
      haversine_km(lat1, lon1, lat2, lon2)
    else
      _ -> nil
    end
  end

  defp haversine_km(lat1, lon1, lat2, lon2) do
    r = 6371.0
    dlat = deg_to_rad(lat2 - lat1)
    dlon = deg_to_rad(lon2 - lon1)

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(deg_to_rad(lat1)) * :math.cos(deg_to_rad(lat2)) *
          :math.sin(dlon / 2) * :math.sin(dlon / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    round(r * c)
  end

  defp deg_to_rad(deg), do: deg * :math.pi() / 180

  defp pronoun("de", "male"), do: "ihn"
  defp pronoun("de", "female"), do: "sie"
  defp pronoun("de", _), do: "die Person"
  defp pronoun(_, "male"), do: "him"
  defp pronoun(_, "female"), do: "her"
  defp pronoun(_, _), do: "them"

  defp summarize_conversation(messages) do
    count = length(messages)

    cond do
      count == 0 -> "new"
      count <= 5 -> "early (#{count} messages)"
      true -> "ongoing (#{count} messages)"
    end
  end

  # --- Prompt building ---

  defp system_instruction("de", age, boldness, other_gender, other_name) do
    age_text = if age, do: "Der User ist #{age} Jahre alt. ", else: ""
    boldness_text = boldness_paragraph("de", boldness)
    pronoun_de = pronoun("de", other_gender)

    """
    Du bist ein Wingman — locker, direkt, ein bisschen frech. #{age_text}Schau dir beide Profile an. Zeig 2 Sachen auf, die auffallen — Gemeinsamkeiten, interessante Details, etwas das neugierig macht. Sag was dir auffällt und schlag ein Gesprächsthema vor, z.B. "Sprich #{pronoun_de} doch mal auf X an." Aber schreib KEINE fertigen Nachrichten oder Formulierungen — nur das Thema nennen, den Rest macht der User selbst.

    #{boldness_text}

    Regeln:
    - Sei locker und direkt — wie ein Kumpel, dem was aufgefallen ist
    - Sprich den User mit "du" an. Nenne das Gegenüber einmal beim Namen ("#{other_name}"), danach nur noch Pronomen (#{pronoun_de}/er/sie). Wenn du über beide sprichst, verwende "ihr" (2. Person Plural): "ihr sucht beide", "ihr lebt beide in" — NIEMALS unpersönliches "Beide suchen", "Beide sind", "beide haben". Beispiel: "#{other_name} mag wie du X — frag #{pronoun_de} doch mal nach Y."
    - Passe deinen Ton ans Alter an: locker bei Jüngeren, etwas gewählter bei Älteren — aber immer auf Augenhöhe
    - KEIN Thema Sex — auch nicht angedeutet. Nicht in den Tipps, nicht im Hook.
    """
    |> String.trim()
  end

  defp system_instruction(lang, age, boldness, other_gender, other_name) do
    age_text = if age, do: "The user is #{age} years old. ", else: ""
    boldness_text = boldness_paragraph("en", boldness)
    pronoun_en = pronoun(lang, other_gender)

    """
    You're a wingman — casual, direct, a little cheeky. #{age_text}Look at both profiles. Point out 2 things that stand out — shared interests, interesting details, something that sparks curiosity. Say what you notice and suggest a conversation topic, e.g. "Ask #{pronoun_en} about X." But do NOT write ready-made messages or phrases — just name the topic, the user writes the message themselves.

    #{boldness_text}

    Rules:
    - Be casual and direct — like a buddy who noticed something
    - Address the user as "you". Mention the other person by name ("#{other_name}") once, then use pronouns (#{pronoun_en}/he/she). When talking about both, use "you both": "you both live in", "you're both into" — NEVER impersonal third person like "Both are", "Both of them", "They both". Example: "#{other_name} also likes X — ask #{pronoun_en} about Y."
    - Adapt your tone to age: relaxed for younger folks, a bit more refined for older ones — but always eye-to-eye
    - NEVER mention sex — not even hinted at. Not in the tips, not in the hook.
    """
    |> String.trim()
  end

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
    role = if language == "de", do: "dein User", else: "your user"
    label = "## #{user.display_name} (#{role})"
    format_profile_section(label, user.display_name, user, language)
  end

  defp other_profile_section(other, language) do
    role = if language == "de", do: "das Gegenüber", else: "the other person"
    label = "## #{other.display_name} (#{role})"
    format_profile_section(label, other.display_name, other, language)
  end

  defp format_profile_section(label, _name, data, language) do
    labels = profile_labels(language)
    gender_label = if language == "de", do: translate_gender(data.gender), else: data.gender

    fields =
      [
        {data.gender, "#{labels.gender}: #{gender_label}"},
        {data.age, "#{labels.age}: #{data.age}"},
        {data.height, "#{labels.height}: #{data.height} cm"},
        {data.city, "#{labels.city}: #{data.city}"},
        {data.occupation, "#{labels.occupation}: #{data.occupation}"}
      ]
      |> Enum.filter(fn {val, _} -> val end)
      |> Enum.map(fn {_, line} -> line end)

    extras =
      format_search_preferences(data, language) ++
        if(data.published_flags != [],
          do: ["#{labels.traits}: #{Enum.join(data.published_flags, ", ")}"],
          else: []
        ) ++
        if(data.stories != [],
          do: ["#{labels.stories}:\n#{Enum.join(data.stories, "\n---\n")}"],
          else: []
        )

    Enum.join([label | fields] ++ extras, "\n")
  end

  defp profile_labels("de") do
    %{
      gender: "Geschlecht",
      age: "Alter",
      height: "Größe",
      city: "Stadt",
      occupation: "Beruf",
      traits: "Eigenschaften",
      stories: "Geschichten"
    }
  end

  defp profile_labels(_language) do
    %{
      gender: "Gender",
      age: "Age",
      height: "Height",
      city: "City",
      occupation: "Occupation",
      traits: "Traits",
      stories: "Stories"
    }
  end

  defp translate_gender("female"), do: "weiblich"
  defp translate_gender("male"), do: "männlich"
  defp translate_gender("diverse"), do: "divers"
  defp translate_gender(other), do: other

  defp format_search_preferences(data, language) do
    {l_age, l_height, l_radius, l_years} =
      if language == "de" do
        {"Sucht Alter", "Sucht Größe", "Suchradius", "Jahre"}
      else
        {"Looking for age", "Looking for height", "Search radius", "years"}
      end

    parts = []

    parts =
      if data.partner_age_min && data.partner_age_max do
        parts ++ ["#{l_age}: #{data.partner_age_min}–#{data.partner_age_max} #{l_years}"]
      else
        parts
      end

    parts =
      if data.partner_height_min && data.partner_height_max do
        parts ++ ["#{l_height}: #{data.partner_height_min}–#{data.partner_height_max} cm"]
      else
        parts
      end

    if data.search_radius do
      parts ++ ["#{l_radius}: #{data.search_radius} km"]
    else
      parts
    end
  end

  defp overlap_section(
         %{shared_traits: shared, compatible_values: compatible},
         distance_km,
         language
       ) do
    parts =
      if distance_km do
        label = if language == "de", do: "Entfernung", else: "Distance"
        ["#{label}: ~#{distance_km} km"]
      else
        []
      end ++
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

  defp wildcard_section(false, _language), do: ""

  defp wildcard_section(true, "de") do
    "Hinweis: Diese Person ist ein Wildcard-Vorschlag — es ist unklar, ob die beiden wirklich Gemeinsamkeiten haben. Erfinde keine Gemeinsamkeiten. Konzentriere dich auf interessante Details aus den Profilen und schlage vor, herauszufinden, ob es eine Verbindung gibt."
  end

  defp wildcard_section(true, _language) do
    "Note: This person is a wildcard suggestion — it's unclear whether they actually have anything in common. Don't invent similarities. Focus on interesting profile details and suggest finding out whether there's a connection."
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
        translated = translate_rating(rating, language)
        "- #{emoji} #{translated}: #{content}"
      end)

    Enum.join([label | lines], "\n")
  end

  defp translate_rating("love", "de"), do: "Liebe"
  defp translate_rating("like", "de"), do: "Gefällt"
  defp translate_rating("dislike", "de"), do: "Gefällt nicht"
  defp translate_rating(rating, _language), do: rating

  defp rating_emoji("love"), do: "❤️"
  defp rating_emoji("like"), do: "👍"
  defp rating_emoji("dislike"), do: "👎"
  defp rating_emoji(_), do: "•"

  defp conversation_section(state, language) do
    if language == "de" do
      "Gesprächsstatus: #{translate_conv_state(state)}"
    else
      "Conversation state: #{state}"
    end
  end

  defp json_instruction("de") do
    """
    Gib NUR gültiges JSON zurück — ein Array mit genau 2 Objekten, jeweils mit den Schlüsseln "text" und "hook":
    [{"text": "was dir aufgefallen ist", "hook": "warum das ein guter Gesprächseinstieg wäre"}, {"text": "noch etwas das dir aufgefallen ist", "hook": "warum das interessant ist"}]
    Beide Schlüssel sind PFLICHT in jedem Objekt. Halte jeden "text" auf 1-2 Sätze. Kein Markdown, keine Erklärung, nur das JSON-Array.
    """
    |> String.trim()
  end

  defp json_instruction(_language) do
    """
    Return ONLY valid JSON — an array of exactly 2 objects, each with "text" and "hook" keys:
    [{"text": "what you noticed", "hook": "why this could be a conversation opener"}, {"text": "another thing you noticed", "hook": "why this is interesting"}]
    Both keys are REQUIRED in every object. Keep each "text" to 1-2 sentences max. No markdown, no explanation, just the JSON array.
    """
    |> String.trim()
  end

  defp translate_conv_state("new"), do: "neu"

  defp translate_conv_state("early (" <> rest),
    do: "Anfang (#{String.replace(rest, " messages)", " Nachrichten)")}"

  defp translate_conv_state("ongoing (" <> rest),
    do: "laufend (#{String.replace(rest, " messages)", " Nachrichten)")}"

  defp translate_conv_state(other), do: other

  defp time_context_section(language) do
    now_berlin =
      TimeMachine.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    time = Calendar.strftime(now_berlin, "%H:%M")
    weekday = berlin_weekday(now_berlin, language)

    if language == "de" do
      "Aktuelle Zeit: #{weekday}, #{time} Uhr (deutsche Zeit)"
    else
      "Current time: #{weekday}, #{time} (German time)"
    end
  end

  defp berlin_weekday(datetime, "de") do
    case Date.day_of_week(DateTime.to_date(datetime)) do
      1 -> "Montag"
      2 -> "Dienstag"
      3 -> "Mittwoch"
      4 -> "Donnerstag"
      5 -> "Freitag"
      6 -> "Samstag"
      7 -> "Sonntag"
    end
  end

  defp berlin_weekday(datetime, _language) do
    case Date.day_of_week(DateTime.to_date(datetime)) do
      1 -> "Monday"
      2 -> "Tuesday"
      3 -> "Wednesday"
      4 -> "Thursday"
      5 -> "Friday"
      6 -> "Saturday"
      7 -> "Sunday"
    end
  end

  # --- JSON extraction ---

  defp extract_json_array(text) do
    # Try complete array first, then truncated
    json_str =
      case Regex.run(~r/\[[\s\S]*\]/s, text) do
        [match] -> match
        nil -> try_close_truncated(text)
      end

    try_decode(json_str)
  end

  defp try_decode(nil), do: :error

  defp try_decode(json_str) do
    case Jason.decode(json_str) do
      {:ok, list} when is_list(list) ->
        {:ok, list}

      _ ->
        repaired = repair_json(json_str)

        case Jason.decode(repaired) do
          {:ok, list} when is_list(list) -> {:ok, list}
          _ -> :error
        end
    end
  end

  # When the LLM output was truncated (no closing "]"), find the last
  # complete JSON object and close the array.
  defp try_close_truncated(text) do
    case Regex.run(~r/\[[\s\S]*/s, text) do
      [partial] ->
        # Find the last complete object (ending with "}")
        case Regex.run(~r/(.*\})\s*,?\s*\{?[\s\S]*$/s, partial) do
          [_, up_to_last_complete] -> up_to_last_complete <> "]"
          nil -> nil
        end

      nil ->
        nil
    end
  end

  # Fix common LLM JSON errors: mismatched braces/parens, trailing commas
  defp repair_json(str) do
    str
    |> String.replace(~r/\"\)(\s*[,\]])/, "\"}\\1")
    |> String.replace(~r/,(\s*[\]\}])/, "\\1")
  end

  # Detect LLM repetition loops: any phrase of 8+ words repeated 4+ times
  defp repetitive?(text) when byte_size(text) < 200, do: false

  defp repetitive?(text) do
    Regex.match?(~r/(\b\w+(?:\s+\w+){7,})\s*(?:.*?\1){3}/s, text)
  end
end
