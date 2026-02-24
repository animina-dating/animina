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
    Gettext.put_locale(AniminaWeb.Gettext, language)
    assigns = prepare_assigns(context, language)
    Animina.Wingman.PromptTemplate.render(language, assigns)
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

  # --- Prompt assigns ---

  defp prepare_assigns(context, language) do
    user = context.user
    other = context.other_user
    overlap = context.overlap
    boldness = compute_boldness(overlap)

    now_berlin =
      TimeMachine.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    translate_flags = fn flags ->
      Enum.map(flags, fn %{category: cat, name: name, intensity: intensity} ->
        %{
          category: AniminaWeb.TraitTranslations.translate(cat),
          name: AniminaWeb.TraitTranslations.translate(name),
          intensity: translate_intensity(intensity)
        }
      end)
    end

    %{
      # System instruction
      user_age: user.age,
      pronoun: pronoun(language, other.gender),
      other_name: other.display_name,
      boldness_text: boldness_paragraph(language, boldness),
      # Time
      weekday: berlin_weekday(now_berlin, language),
      time: Calendar.strftime(now_berlin, "%H:%M"),
      # User profile
      user_name: user.display_name,
      user_gender: user.gender,
      user_gender_label: translate_gender(user.gender),
      user_height: user.height,
      user_city: user.city,
      user_occupation: user.occupation,
      user_partner_age_min: user.partner_age_min,
      user_partner_age_max: user.partner_age_max,
      user_partner_height_min: user.partner_height_min,
      user_partner_height_max: user.partner_height_max,
      user_search_radius: user.search_radius,
      user_white_flags_published: translate_flags.(user.white_flags_published),
      user_white_flags_private: translate_flags.(user.white_flags_private),
      user_green_flags: translate_flags.(user.green_flags),
      user_stories: user.stories,
      # Other user profile (strip private flags)
      other_gender: other.gender,
      other_gender_label: translate_gender(other.gender),
      other_age: other.age,
      other_height: other.height,
      other_city: other.city,
      other_occupation: other.occupation,
      other_partner_age_min: other.partner_age_min,
      other_partner_age_max: other.partner_age_max,
      other_partner_height_min: other.partner_height_min,
      other_partner_height_max: other.partner_height_max,
      other_search_radius: other.search_radius,
      other_white_flags_published: translate_flags.(other.white_flags_published),
      other_green_flags: translate_flags.(other.green_flags),
      other_stories: other.stories,
      # Overlap
      distance_km: context.distance_km,
      overlap_public: Enum.map(overlap.shared_traits_public, &translate_overlap_name/1),
      overlap_private_categories:
        overlap.shared_traits_private |> Enum.map(&extract_category/1) |> Enum.uniq(),
      overlap_compatible: Enum.map(overlap.compatible_values, &translate_overlap_name/1),
      # Wildcard
      is_wildcard: Map.get(context, :is_wildcard, false),
      # Ratings
      ratings:
        Enum.map(context.user_ratings, fn %{rating: rating, content: content} ->
          %{
            emoji: rating_emoji(rating),
            label: translate_rating(rating, language),
            content: content
          }
        end),
      # Conversation
      conversation_state: translate_conv_state(context.conversation_state, language)
    }
  end

  # --- Prompt helpers (used by prepare_assigns) ---

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

  defp translate_overlap_name(name) do
    case String.split(name, ": ", parts: 2) do
      [cat, flag] ->
        "#{AniminaWeb.TraitTranslations.translate(cat)}: #{AniminaWeb.TraitTranslations.translate(flag)}"

      _ ->
        AniminaWeb.TraitTranslations.translate(name)
    end
  end

  defp extract_category(name) do
    case String.split(name, ": ", parts: 2) do
      [cat, _] -> AniminaWeb.TraitTranslations.translate(cat)
      _ -> AniminaWeb.TraitTranslations.translate(name)
    end
  end

  defp translate_intensity(intensity) do
    case {Gettext.get_locale(AniminaWeb.Gettext), intensity} do
      {"de", "hard"} -> "wichtig"
      {"de", "soft"} -> "flexibel"
      {_, i} -> i
    end
  end

  defp translate_gender("female"), do: "weiblich"
  defp translate_gender("male"), do: "männlich"
  defp translate_gender("diverse"), do: "divers"
  defp translate_gender(other), do: other

  defp translate_rating("love", "de"), do: "Liebe"
  defp translate_rating("like", "de"), do: "Gefällt"
  defp translate_rating("dislike", "de"), do: "Gefällt nicht"
  defp translate_rating(rating, _language), do: rating

  defp rating_emoji("love"), do: "❤️"
  defp rating_emoji("like"), do: "👍"
  defp rating_emoji("dislike"), do: "👎"
  defp rating_emoji(_), do: "•"

  defp translate_conv_state("new", "de"), do: "neu"
  defp translate_conv_state("new", _), do: "new"

  defp translate_conv_state("early (" <> rest, "de"),
    do: "Anfang (#{String.replace(rest, " messages)", " Nachrichten)")}"

  defp translate_conv_state("ongoing (" <> rest, "de"),
    do: "laufend (#{String.replace(rest, " messages)", " Nachrichten)")}"

  defp translate_conv_state(other, _language), do: other

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
