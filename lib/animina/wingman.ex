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
  - Private white flags: NEVER sent to the LLM. Instead, private overlaps
    are pre-computed into structured conversation hints in Elixir code so the
    LLM only sees "Suggest asking if the other person also enjoys X"
  - Sex-related categories (Sexual Preferences, Sexual Practices) are
    excluded from private overlap hints entirely
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
  alias Animina.Wingman.PreheatedWingmanHint
  alias Animina.Wingman.PromptTemplate
  alias Animina.Wingman.WingmanFeedback
  alias Animina.Wingman.WingmanSuggestion

  require Logger

  @max_story_chars 1500

  # Categories excluded from prompt data — too obvious or not a good conversation starter
  @trivial_categories MapSet.new(["Relationship Status", "What I'm Looking For"])
  # Sex-related categories excluded from private overlap hints (the prompt already bans sex topics)
  @sex_categories MapSet.new(["Sexual Preferences", "Sexual Practices"])
  # Map GUI language codes to language flag names — used to strip the shared
  # GUI language from data sent to the LLM (it's obvious and not a conversation topic)
  @language_code_to_flag %{
    "de" => "Deutsch",
    "en" => "English",
    "tr" => "Türkçe",
    "ru" => "Русский",
    "ar" => "العربية",
    "pl" => "Polski",
    "fr" => "Français",
    "es" => "Español",
    "uk" => "Українська"
  }
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
        # Check preheated hints before on-demand generation
        case get_preheated_hint(user_id, other_user_id) do
          %PreheatedWingmanHint{suggestions: suggestions} when is_list(suggestions) ->
            # Promote to wingman_suggestions so feedback/deletion works unchanged
            save_and_broadcast(conversation_id, user_id, suggestions, nil, nil)
            {:ok, suggestions}

          _ ->
            enqueue_generation(conversation_id, user_id, other_user_id)
        end
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

  Returns a map with `:user`, `:other_user`, and `:overlap`.
  """
  def gather_context(requesting_user, other_user, _messages) do
    requesting_user = Repo.preload(requesting_user, :locations)
    other_user = Repo.preload(other_user, :locations)

    user_data = gather_user_data(requesting_user)
    other_user_data = gather_user_data(other_user)

    trivial_lang_flags = trivial_language_flags(requesting_user, other_user)
    overlap = gather_safe_overlap(requesting_user, other_user, trivial_lang_flags)
    user_ratings = gather_user_ratings(requesting_user.id, other_user.id)
    distance_km = compute_distance(requesting_user, other_user)
    is_wildcard = wildcard?(requesting_user.id, other_user.id)

    %{
      user: user_data,
      other_user: other_user_data,
      overlap: overlap,
      trivial_lang_flags: trivial_lang_flags,
      user_ratings: user_ratings,
      distance_km: distance_km,
      is_wildcard: is_wildcard
    }
  end

  # --- Preheated Hints API ---

  @doc """
  Saves or updates a preheated wingman hint via upsert.
  """
  def save_preheated_hint(user_id, other_user_id, shown_on, suggestions, context_hash, ai_job_id) do
    attrs = %{
      user_id: user_id,
      other_user_id: other_user_id,
      shown_on: shown_on,
      suggestions: suggestions,
      context_hash: context_hash,
      ai_job_id: ai_job_id
    }

    %PreheatedWingmanHint{}
    |> PreheatedWingmanHint.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:suggestions, :context_hash, :ai_job_id, :updated_at]},
      conflict_target: [:user_id, :other_user_id, :shown_on]
    )
  end

  @doc """
  Looks up a preheated hint for today (Berlin time).
  Returns nil if no hint exists or suggestions are nil.
  """
  def get_preheated_hint(user_id, other_user_id) do
    today = berlin_today()

    from(h in PreheatedWingmanHint,
      where:
        h.user_id == ^user_id and
          h.other_user_id == ^other_user_id and
          h.shown_on == ^today and
          not is_nil(h.suggestions)
    )
    |> Repo.one()
  end

  @doc """
  Deletes all today's preheated hints where the user appears on either side.
  Called when a user edits their moodboard or flags, making hints stale.
  """
  def invalidate_preheated_hints(user_id) do
    today = berlin_today()

    from(h in PreheatedWingmanHint,
      where: (h.user_id == ^user_id or h.other_user_id == ^user_id) and h.shown_on == ^today
    )
    |> Repo.delete_all()
  end

  @doc """
  Deletes preheated hints older than today (Berlin time).
  """
  def cleanup_old_preheated_hints do
    today = berlin_today()

    {count, _} =
      from(h in PreheatedWingmanHint, where: h.shown_on < ^today)
      |> Repo.delete_all()

    if count > 0, do: Logger.info("Wingman: Cleaned up #{count} old preheated hint(s)")
    count
  end

  defp berlin_today do
    TimeMachine.utc_now()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> DateTime.to_date()
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
    PromptTemplate.render(language, assigns)
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
      language: user.language || "de",
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

  defp gather_safe_overlap(user_a, user_b, trivial_lang_flags) do
    overlap = Matching.compute_flag_overlap(user_a, user_b)

    # Get published category IDs for both users to determine visibility
    a_published = MapSet.new(Traits.list_published_white_flag_category_ids(user_a))
    b_published = MapSet.new(Traits.list_published_white_flag_category_ids(user_b))

    {public_shared, private_shared} =
      split_overlap_by_visibility(
        overlap.white_white,
        a_published,
        b_published,
        trivial_lang_flags
      )

    green_white_names =
      resolve_flag_names(overlap.green_white) |> filter_trivial_overlap(trivial_lang_flags)

    %{
      shared_traits_public: public_shared,
      shared_traits_private: private_shared,
      compatible_values: green_white_names
    }
  end

  # Splits shared white-white flag IDs into public (both published) vs private (at least one private)
  defp split_overlap_by_visibility([], _a_pub, _b_pub, _trivial), do: {[], []}

  defp split_overlap_by_visibility(flag_ids, a_published, b_published, trivial_lang_flags) do
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

    public_names = format_flag_overlap_names(public) |> filter_trivial_overlap(trivial_lang_flags)

    private_names =
      format_flag_overlap_names(private) |> filter_trivial_overlap(trivial_lang_flags)

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

  defp filter_trivial_overlap(names, trivial_language_flags) do
    Enum.reject(names, fn name ->
      MapSet.member?(trivial_language_flags, name) or
        Enum.any?(
          MapSet.union(@trivial_categories, @abstract_overlap_categories),
          &String.starts_with?(name, &1)
        )
    end)
  end

  # Rejects overlap name strings whose category prefix matches @trivial_categories.
  # Used in prepare_assigns as defense-in-depth (overlap names are "Category: Flag").
  defp reject_trivial_category_names(names) do
    Enum.reject(names, fn name ->
      Enum.any?(@trivial_categories, &String.starts_with?(name, &1))
    end)
  end

  # Rejects individual green/white flags whose category is in @trivial_categories.
  defp reject_trivial_flag_category(flags) do
    Enum.reject(flags, fn %{category: cat} -> MapSet.member?(@trivial_categories, cat) end)
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

  # When both users share the same GUI language, that language as a flag is
  # trivial (e.g. both use German UI → "Languages: Deutsch" is obvious).
  # Returns a MapSet of "Languages: FlagName" strings to strip from all data.
  defp trivial_language_flags(user_a, user_b) do
    lang_a = user_a.language || "de"
    lang_b = user_b.language || "de"

    if lang_a == lang_b do
      case Map.get(@language_code_to_flag, lang_a) do
        nil -> MapSet.new()
        flag_name -> MapSet.new(["Languages: #{flag_name}"])
      end
    else
      MapSet.new()
    end
  end

  # Removes the shared GUI language from a list of white flag maps
  defp strip_gui_language_flags(flags, trivial_lang_flags) do
    if MapSet.size(trivial_lang_flags) == 0 do
      flags
    else
      trivial_names = MapSet.new(trivial_lang_flags, &extract_flag_name/1)

      Enum.reject(flags, fn %{category: cat, name: name} ->
        cat == "Languages" and MapSet.member?(trivial_names, name)
      end)
    end
  end

  defp extract_flag_name(entry) do
    case String.split(entry, ": ", parts: 2) do
      [_cat, name] -> name
      _ -> entry
    end
  end

  defp pronoun("de", "male"), do: "ihn"
  defp pronoun("de", "female"), do: "sie"
  defp pronoun("de", _), do: "die Person"
  defp pronoun(_, "male"), do: "him"
  defp pronoun(_, "female"), do: "her"
  defp pronoun(_, _), do: "them"

  defp possessive_pronoun("de", "male"), do: "seiner"
  defp possessive_pronoun("de", "female"), do: "ihrer"
  defp possessive_pronoun("de", _), do: "deren"
  defp possessive_pronoun(_, "male"), do: "his"
  defp possessive_pronoun(_, "female"), do: "her"
  defp possessive_pronoun(_, _), do: "their"

  # --- Prompt assigns ---

  defp prepare_assigns(context, language) do
    user = context.user
    other = context.other_user

    # Filter out trivial categories from overlap (defense-in-depth; gather_safe_overlap does this
    # too, but tests and future code paths may inject overlap values directly)
    overlap = %{
      context.overlap
      | shared_traits_public: reject_trivial_category_names(context.overlap.shared_traits_public),
        shared_traits_private:
          reject_trivial_category_names(context.overlap.shared_traits_private),
        compatible_values: reject_trivial_category_names(context.overlap.compatible_values)
    }

    boldness = compute_boldness(overlap)

    now_berlin =
      TimeMachine.utc_now()
      |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)

    # Strip shared GUI language from individual white flags (it's obvious, not a conversation topic)
    trivial_lang = Map.get(context, :trivial_lang_flags, MapSet.new())
    user_white_filtered = strip_gui_language_flags(user.white_flags_published, trivial_lang)
    other_white_filtered = strip_gui_language_flags(other.white_flags_published, trivial_lang)

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
      possessive_pronoun: possessive_pronoun(language, other.gender),
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
      user_white_flags_published: translate_flags.(user_white_filtered),
      user_green_flags: translate_flags.(reject_trivial_flag_category(user.green_flags)),
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
      other_white_flags_published: translate_flags.(other_white_filtered),
      other_green_flags: translate_flags.(reject_trivial_flag_category(other.green_flags)),
      other_stories: other.stories,
      # Overlap
      distance_km: context.distance_km,
      overlap_public: Enum.map(overlap.shared_traits_public, &translate_overlap_name/1),
      overlap_private_hints: build_private_overlap_hints(overlap.shared_traits_private, language),
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
        end)
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

  defp build_private_overlap_hints(shared_traits_private, language) do
    shared_traits_private
    |> Enum.reject(fn name ->
      case String.split(name, ": ", parts: 2) do
        [cat, _] -> MapSet.member?(@sex_categories, cat)
        _ -> false
      end
    end)
    |> Enum.take(20)
    |> Enum.map(&private_hint_for_flag(&1, language))
    |> Enum.reject(&is_nil/1)
  end

  defp private_hint_for_flag(name, language) do
    case String.split(name, ": ", parts: 2) do
      [_cat, flag] ->
        translated = AniminaWeb.TraitTranslations.translate(flag)

        if language == "de",
          do:
            "Dein User mag: #{translated}. Schlage vor zu fragen, ob das Gegenüber auch #{translated} mag.",
          else:
            "Your user likes: #{translated}. Suggest asking if the other person also enjoys #{translated}."

      _ ->
        nil
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
