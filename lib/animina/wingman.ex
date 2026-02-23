defmodule Animina.Wingman do
  @moduledoc """
  Context for AI-powered conversation coaching ("Wingman").

  Generates personalized conversation tips using profile data with flag-level
  privacy handling. Uses the Ollama AI queue for async generation.

  ## Privacy Rules

  - Uses freely: moodboard stories, published white flags (by name),
    occupation, city, age
  - Uses delicately: green flags (framed as shared values), white_white and
    green_white overlap
  - Private white flags: included for context but the LLM is instructed to
    NEVER mention them by name — only generic category-level references
  - Never uses: red flags, red_white conflicts, sensitive categories without
    mutual opt-in
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

  # Categories that are too obvious for conversation tips on a German dating platform
  @trivial_categories MapSet.new(["Relationship Status"])
  # Flag names that are trivial when shared (everyone on a German platform speaks German)
  @trivial_shared_flags MapSet.new(["Languages: Deutsch"])
  # Categories too abstract for overlap — nobody says "I'm dishonest", so asking is pointless.
  # These still appear in individual profiles for context, just not in the "shared traits" section.
  @abstract_overlap_categories MapSet.new(["Character"])

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
    # Set Gettext locale so TraitTranslations.translate/1 returns the right language
    Gettext.put_locale(AniminaWeb.Gettext, language)

    user = context.user
    other = context.other_user
    overlap = context.overlap
    conv_state = context.conversation_state

    is_wildcard = Map.get(context, :is_wildcard, false)
    boldness = compute_boldness(overlap)

    system_instruction =
      system_instruction(language, user.age, boldness, other.gender, other.display_name)

    time_section = time_context_section(language)
    moodboard_explanation = moodboard_explanation_section(language)
    flag_system = flag_system_section(language)
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
        moodboard_explanation,
        flag_system,
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

      case AI.enqueue("wingman_suggestion", params,
             requester_id: user_id,
             expires_at: DateTime.utc_now() |> DateTime.add(60, :second)
           ) do
        {:ok, job} -> {:pending, job.id}
        error -> error
      end
    end
  end

  defp gather_user_data(user) do
    # Reload user with locations
    user = Repo.preload(user, :locations)

    stories = gather_stories(user.id)
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
      white_flags_published: gather_white_flags(user, :published),
      white_flags_private: gather_white_flags(user, :private),
      green_flags: gather_green_flags(user)
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

  defp gather_white_flags(user, visibility) do
    all_white = Traits.list_user_flags_with_category(user, "white")
    published_cat_ids = Traits.list_published_white_flag_category_ids(user)
    published_cat_ids_set = MapSet.new(published_cat_ids)

    all_white
    |> Enum.filter(fn uf ->
      cat_id = uf.flag.category_id
      is_published = MapSet.member?(published_cat_ids_set, cat_id)
      not_trivial = not MapSet.member?(@trivial_categories, uf.flag.category.name)

      not_trivial and
        case visibility do
          :published -> is_published
          :private -> not is_published
        end
    end)
    |> Enum.map(fn uf ->
      %{
        category: uf.flag.category.name || "",
        name: uf.flag.name || "",
        intensity: uf.intensity || "hard"
      }
    end)
  end

  defp gather_green_flags(user) do
    Traits.list_user_flags_with_category(user, "green")
    |> Enum.reject(fn uf -> MapSet.member?(@trivial_categories, uf.flag.category.name) end)
    |> Enum.map(fn uf ->
      %{
        category: uf.flag.category.name || "",
        name: uf.flag.name || "",
        intensity: uf.intensity || "hard"
      }
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

    # Get published category IDs for both users to determine visibility
    a_published = MapSet.new(Traits.list_published_white_flag_category_ids(user_a))
    b_published = MapSet.new(Traits.list_published_white_flag_category_ids(user_b))

    {public_shared, private_shared} =
      split_overlap_by_visibility(overlap.white_white, a_published, b_published)

    green_white_names = resolve_flag_names(overlap.green_white) |> filter_trivial_overlap()

    %{
      shared_traits_public: public_shared,
      shared_traits_private: private_shared,
      compatible_values: green_white_names
    }
  end

  # Splits shared white-white flag IDs into public (both published) vs private (at least one private)
  defp split_overlap_by_visibility([], _a_pub, _b_pub), do: {[], []}

  defp split_overlap_by_visibility(flag_ids, a_published, b_published) do
    flags =
      from(f in Animina.Traits.Flag,
        where: f.id in ^flag_ids,
        preload: [:category]
      )
      |> Repo.all()

    {public, private} =
      Enum.split_with(flags, fn flag ->
        MapSet.member?(a_published, flag.category_id) and
          MapSet.member?(b_published, flag.category_id)
      end)

    public_names = format_flag_overlap_names(public) |> filter_trivial_overlap()
    private_names = format_flag_overlap_names(private) |> filter_trivial_overlap()
    {public_names, private_names}
  end

  defp format_flag_overlap_names(flags) do
    Enum.map(flags, fn
      %{name: name, category: %{name: category_name}} ->
        "#{category_name || ""}: #{name || ""}" |> String.trim()

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp filter_trivial_overlap(names) do
    Enum.reject(names, fn name ->
      MapSet.member?(@trivial_shared_flags, name) or
        Enum.any?(
          MapSet.union(@trivial_categories, @abstract_overlap_categories),
          &String.starts_with?(name, &1)
        )
    end)
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

  defp moodboard_explanation_section("de") do
    """
    ## Was ist das Moodboard?
    Das Moodboard ist das visuelle Profil — ein Raster aus Fotos, Textgeschichten und kombinierten Karten. Die unten gezeigten "Geschichten" sind die selbstgeschriebenen Texte aus den Moodboard-Einträgen. Sie sind persönlich und kreativ — behandle sie als Einblick in die Persönlichkeit.
    """
    |> String.trim()
  end

  defp moodboard_explanation_section(_language) do
    """
    ## What is the Moodboard?
    The moodboard is the visual profile — a grid of photos, text stories, and combined cards. The "stories" shown below are the self-written texts from moodboard items. They are personal and creative — treat them as personality insight.
    """
    |> String.trim()
  end

  defp flag_system_section("de") do
    """
    ## Flaggen-System
    - Weiße Flaggen = eigene Eigenschaften ("Ich bin so")
    - Grüne Flaggen = was man beim Partner sucht ("Ich wünsche mir das")
    - wichtig = sehr wichtig / nicht verhandelbar
    - flexibel = wäre schön / flexibel
    - Sichtbarkeit: Öffentliche weiße Flaggen dürfen beim Namen genannt werden. Private weiße Flaggen NIEMALS beim Namen nennen — nur allgemein auf Kategorie-Ebene verweisen.
    - Flaggen sind WICHTIGER als Geschichten — beides zählt, aber Flaggen sind strukturierter und aussagekräftiger.
    """
    |> String.trim()
  end

  defp flag_system_section(_language) do
    """
    ## Flag System
    - White flags = personal traits ("I am like this")
    - Green flags = what you want in a partner ("I want this")
    - hard = very important / non-negotiable
    - soft = nice to have / flexible
    - Visibility: Public white flags may be mentioned by name. Private white flags NEVER by name — only generic category-level references.
    - Flags are MORE important than stories — both matter, but flags are more structured and definitive.
    """
    |> String.trim()
  end

  defp system_instruction("de", age, boldness, other_gender, other_name) do
    age_text = if age, do: "Der User ist #{age} Jahre alt. ", else: ""
    boldness_text = boldness_paragraph("de", boldness)
    pronoun_de = pronoun("de", other_gender)

    """
    Das hier ist ANIMINA, eine Online-Dating-Plattform. Der User möchte die erste Nachricht an das Gegenüber schreiben — die beiden kennen sich noch nicht. Du bist ein Wingman — locker, direkt, ein bisschen frech. #{age_text}Schau dir beide Profile an. Zeig 2 Sachen auf, die auffallen — Gemeinsamkeiten, interessante Details, etwas das neugierig macht. Sag was dir auffällt und schlag ein Gesprächsthema vor, z.B. "Sprich #{pronoun_de} doch mal auf X an." Aber schreib KEINE fertigen Nachrichten oder Formulierungen — nur das Thema nennen, den Rest macht der User selbst.

    #{boldness_text}

    Regeln:
    - Sei locker und direkt — wie ein Kumpel, dem was aufgefallen ist
    - Sprich den User mit "du" an. Nenne das Gegenüber einmal beim Namen ("#{other_name}"), danach nur noch Pronomen (#{pronoun_de}/er/sie). Wenn du über beide sprichst, verwende "ihr" (2. Person Plural): "ihr sucht beide", "ihr lebt beide in" — NIEMALS unpersönliches "Beide suchen", "Beide sind", "beide haben". Beispiel: "#{other_name} mag wie du X — frag #{pronoun_de} doch mal nach Y."
    - Passe deinen Ton ans Alter an: locker bei Jüngeren, etwas gewählter bei Älteren — aber immer auf Augenhöhe
    - KEIN Thema Sex — auch nicht angedeutet. Nicht in den Tipps, nicht im Hook.
    - Öffentliche weiße Flaggen darfst du beim Namen nennen. Private weiße Flaggen NICHT beim Namen nennen — nur allgemein auf die Kategorie verweisen.
    - Flaggen sind wichtiger als Geschichten — nutze sie als primäre Quelle für Tipps.
    - Dass beide Single sind, ist KEIN Gesprächsthema — auf einer Dating-Plattform ist das selbstverständlich. Dass beide Deutsch sprechen, ist ebenfalls kein Thema — das ist eine deutsche Plattform. Nur ANDERE gemeinsame Sprachen (z.B. Spanisch, Französisch) sind interessant.
    - Wenn ein Hinweis sagt "der User hat Interessen in Bereich X, die das Gegenüber eventuell teilt", erwähne NUR die Eigenschaft des Users und schlage vor zu fragen. NIEMALS behaupten, dass das Gegenüber das auch mag. Frag dabei NICHT nach der übergeordneten Kategorie, wenn der User eine konkrete Aktivität hat — "Du surfst gerne — frag #{pronoun_de}, ob #{pronoun_de} auch Sport macht" ist Unsinn, weil Surfen bereits Sport ist. Besser: "Du bist sportlich unterwegs — frag #{pronoun_de} doch mal, welche Sportarten #{pronoun_de} mag."
    - Bekannte Gemeinsamkeiten (aus "Gemeinsame Eigenschaften" oder "Kompatible Werte") sind FAKTEN — nutze sie als Gesprächseinstieg ("Ihr surft beide — sprich #{pronoun_de} darauf an!"), frag aber NICHT danach als wäre es unbekannt.
    - Erwähne NUR Eigenschaften und Hobbys, die tatsächlich in den Profilen stehen. Erfinde keine Aktivitäten oder Interessen dazu.
    - Grüne Flaggen zeigen, was jemand beim PARTNER sucht — nicht was die Person selbst tut. Wenn jemand "Sport: Radfahren" als grüne Flagge hat, sucht die Person einen Partner der Rad fährt — das heißt nicht, dass sie selbst Rad fährt.
    - Verwende NIEMALS "ich", "mir" oder "mich" — du bist ein KI-Wingman, kein Mensch. Du sprichst ÜBER den User ("du"), nicht ALS der User.
    - Abstrakte Charaktereigenschaften (Ehrlichkeit, Empathie, Humor, Mut, Intelligenz etc.) sind KEINE guten Gesprächsthemen — niemand sagt "Ich bin unehrlich". Bevorzuge konkrete Hobbys, Interessen und Erlebnisse als Gesprächseinstieg. Charakter-Flaggen dürfen als Kontext erwähnt werden, aber schlage nicht vor, danach zu fragen.
    """
    |> String.trim()
  end

  defp system_instruction(lang, age, boldness, other_gender, other_name) do
    age_text = if age, do: "The user is #{age} years old. ", else: ""
    boldness_text = boldness_paragraph("en", boldness)
    pronoun_en = pronoun(lang, other_gender)

    """
    This is ANIMINA, an online dating platform. The user is about to write the first message to the other person — they don't know each other yet. You're a wingman — casual, direct, a little cheeky. #{age_text}Look at both profiles. Point out 2 things that stand out — shared interests, interesting details, something that sparks curiosity. Say what you notice and suggest a conversation topic, e.g. "Ask #{pronoun_en} about X." But do NOT write ready-made messages or phrases — just name the topic, the user writes the message themselves.

    #{boldness_text}

    Rules:
    - Be casual and direct — like a buddy who noticed something
    - Address the user as "you". Mention the other person by name ("#{other_name}") once, then use pronouns (#{pronoun_en}/he/she). When talking about both, use "you both": "you both live in", "you're both into" — NEVER impersonal third person like "Both are", "Both of them", "They both". Example: "#{other_name} also likes X — ask #{pronoun_en} about Y."
    - Adapt your tone to age: relaxed for younger folks, a bit more refined for older ones — but always eye-to-eye
    - NEVER mention sex — not even hinted at. Not in the tips, not in the hook.
    - Published white flags may be named. Private white flags NEVER by name — only generic category references.
    - Flags are more important than stories — use them as primary source for tips.
    - Both being single is NOT a conversation topic — it's obvious on a dating platform. Both speaking German is also not a topic — it's a German platform. Only OTHER shared languages (e.g. Spanish, French) are interesting.
    - When a hint says "the user has interests in area X that the other person might share", only mention the USER'S trait and suggest asking. NEVER claim the other person also likes it. Do NOT ask about the parent category when the user has a specific activity — "You like surfing — ask #{pronoun_en} if #{pronoun_en} is into sports" is nonsense because surfing IS a sport. Better: "You're into sports — ask #{pronoun_en} what sports #{pronoun_en} enjoys."
    - Known shared traits (from "Things in common" or "Compatible values") are FACTS — use them as conversation starters ("You both surf — bring that up!"), don't ask about them as if they're unknown.
    - Only mention traits and hobbies that actually appear in the profiles. Do not invent activities or interests.
    - Green flags show what someone SEEKS in a partner — not what they do themselves. If someone has "Sport: Cycling" as a green flag, they want a partner who cycles — it doesn't mean they cycle themselves.
    - NEVER use "I", "me" or "my" — you are an AI wingman, not a person. Talk ABOUT the user ("you"), not AS the user.
    - Abstract character traits (honesty, empathy, humor, courage, intelligence etc.) are NOT good conversation topics — nobody says "I'm dishonest". Prefer concrete hobbies, interests and experiences as conversation starters. Character flags may be mentioned as context, but don't suggest asking about them.
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

  defp compute_boldness(%{
         shared_traits_public: public,
         shared_traits_private: private,
         compatible_values: compatible
       }) do
    all_shared = public ++ private

    cond do
      all_shared != [] and compatible != [] -> :bold
      all_shared != [] or compatible != [] -> :moderate
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
    # Strip private flags — the LLM must not see what isn't public
    safe_other = %{other | white_flags_private: []}
    format_profile_section(label, other.display_name, safe_other, language)
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
        format_flag_subsections(data, language) ++
        if(data.stories != [],
          do: ["#{labels.stories}:\n#{Enum.join(data.stories, "\n---\n")}"],
          else: []
        )

    Enum.join([label | fields] ++ extras, "\n")
  end

  defp format_flag_subsections(data, language) do
    {white_pub_label, white_priv_label, green_label} =
      if language == "de" do
        {"Weiße Flaggen (eigene Eigenschaften) — Öffentlich",
         "Weiße Flaggen (eigene Eigenschaften) — Privat — NICHT beim Namen nennen!",
         "Grüne Flaggen (sucht beim Partner)"}
      else
        {"White flags (own traits) — Public",
         "White flags (own traits) — Private — NEVER mention by name!",
         "Green flags (looking for in partner)"}
      end

    sections = []

    sections =
      if data.white_flags_published != [] do
        lines = Enum.map(data.white_flags_published, &format_flag/1)
        sections ++ ["#{white_pub_label}:\n#{Enum.join(lines, "\n")}"]
      else
        sections
      end

    sections =
      if data.white_flags_private != [] do
        lines = Enum.map(data.white_flags_private, &format_flag/1)
        sections ++ ["#{white_priv_label}:\n#{Enum.join(lines, "\n")}"]
      else
        sections
      end

    if data.green_flags != [] do
      lines = Enum.map(data.green_flags, &format_flag/1)
      sections ++ ["#{green_label}:\n#{Enum.join(lines, "\n")}"]
    else
      sections
    end
  end

  # Gettext locale is set in build_prompt/2, so translate/1 returns the right language
  defp format_flag(%{category: category, name: name, intensity: intensity}) do
    cat = AniminaWeb.TraitTranslations.translate(category)
    flag = AniminaWeb.TraitTranslations.translate(name)
    intensity_label = translate_intensity(intensity)
    "- #{cat}: #{flag} (#{intensity_label})"
  end

  # Overlap names are stored as "CategoryName: FlagName" — translate each part
  defp translate_overlap_name(name) do
    case String.split(name, ": ", parts: 2) do
      [cat, flag] ->
        "#{AniminaWeb.TraitTranslations.translate(cat)}: #{AniminaWeb.TraitTranslations.translate(flag)}"

      _ ->
        AniminaWeb.TraitTranslations.translate(name)
    end
  end

  defp translate_intensity(intensity) do
    case {Gettext.get_locale(AniminaWeb.Gettext), intensity} do
      {"de", "hard"} -> "wichtig"
      {"de", "soft"} -> "flexibel"
      {_, i} -> i
    end
  end

  defp profile_labels("de") do
    %{
      gender: "Geschlecht",
      age: "Alter",
      height: "Größe",
      city: "Stadt",
      occupation: "Beruf",
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
         %{
           shared_traits_public: public_shared,
           shared_traits_private: private_shared,
           compatible_values: compatible
         },
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
        if public_shared != [] do
          label =
            if language == "de",
              do: "Gemeinsame Eigenschaften (beide öffentlich — darfst du nennen)",
              else: "Things in common (both public — you may name these)"

          translated = Enum.map(public_shared, &translate_overlap_name/1)
          ["#{label}: #{Enum.join(translated, ", ")}"]
        else
          []
        end ++
        if private_shared != [] do
          label =
            if language == "de",
              do:
                "Hinweis: Der User hat Interessen in diesen Bereichen, die das Gegenüber eventuell teilt. Schlage vor, danach zu fragen — aber verrate NICHT, dass das Gegenüber das auch mag",
              else:
                "Hint: The user has interests in these areas that the other person might share. Suggest asking about them — but do NOT reveal the other person shares them"

          # Only show the category, not the specific flag — to prevent leaking
          categories =
            private_shared
            |> Enum.map(fn name ->
              case String.split(name, ": ", parts: 2) do
                [cat, _] -> AniminaWeb.TraitTranslations.translate(cat)
                _ -> AniminaWeb.TraitTranslations.translate(name)
              end
            end)
            |> Enum.uniq()

          ["#{label}: #{Enum.join(categories, ", ")}"]
        else
          []
        end ++
        if compatible != [] do
          label = if language == "de", do: "Kompatible Werte", else: "Compatible values"
          translated = Enum.map(compatible, &translate_overlap_name/1)
          ["#{label}: #{Enum.join(translated, ", ")}"]
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
