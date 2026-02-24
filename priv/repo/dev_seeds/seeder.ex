defmodule Animina.Seeds.DevUsers do
  @moduledoc """
  Seeds development test accounts with full profiles, traits, and moodboards.
  114 users with personality profiles, topic-matched moodboards, and login activity.
  All accounts use the password "password12345".
  Avatars use real Unsplash photos stored in priv/static/images/seeds/avatars/.

  Story content is split across files in priv/repo/dev_seeds/:
    - personas.ex — persona definitions with character descriptions
    - stories.ex  — unique intros, topic stories, long stories, photos
    - profiles.ex — personality trait profiles
    - seeder.ex   — this file: seeding logic
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.Accounts.ContactBlacklist
  alias Animina.ActivityLog.ActivityLogEntry
  alias Animina.GeoData
  alias Animina.Moodboard
  alias Animina.Photos
  alias Animina.Repo
  alias Animina.Seeds.Personas
  alias Animina.Seeds.Profiles
  alias Animina.Seeds.Stories
  alias Animina.Traits

  @password "password12345"
  @zip_code "56068"

  # ==========================================================================
  # SEEDING ENTRY POINT
  # ==========================================================================
  def seed_all do
    IO.puts("\n=== Seeding Development Users ===\n")

    country = GeoData.get_country_by_code("DE")

    unless country do
      raise "Germany (DE) not found in countries table. Run geo data seeds first."
    end

    lookup = build_flag_lookup()
    personas = Personas.all()
    personality_profiles = Profiles.all()
    persona_intros = Stories.persona_intros()
    topic_stories = Stories.topic_stories()
    topic_photos = Stories.topic_photos()
    long_stories = Stories.long_stories()

    IO.puts("Creating #{length(personas)} users...")

    for {persona, index} <- Enum.with_index(personas) do
      create_persona(persona, country.id, index, lookup, %{
        personality_profiles: personality_profiles,
        persona_intros: persona_intros,
        topic_stories: topic_stories,
        topic_photos: topic_photos,
        long_stories: long_stories
      })
    end

    IO.puts("\n=== Development Users Seeded Successfully ===")
    IO.puts("Total users created: #{length(personas)}")
    IO.puts("Password for all: #{@password}\n")
  end

  # ==========================================================================
  # USER CREATION
  # ==========================================================================
  defp create_persona(persona, country_id, index, lookup, content) do
    birthday = birthday_from_age(persona.age)
    phone = generate_phone(index)
    gender = persona.gender
    preferred_gender = if gender == "male", do: ["female"], else: ["male"]
    zip_code = Map.get(persona, :zip_code, @zip_code)

    email =
      if index == 0,
        do: "dev-thomas@animina.test",
        else: "dev-#{email_slug(persona.name)}-#{email_slug(persona.last_name)}@animina.test"

    height =
      Map.get_lazy(persona, :height, fn ->
        if gender == "male", do: Enum.random(170..195), else: Enum.random(155..180)
      end)

    attrs =
      %{
        email: email,
        password: @password,
        first_name: persona.name,
        last_name: persona.last_name,
        display_name: persona.name,
        birthday: birthday,
        gender: gender,
        height: height,
        mobile_phone: phone,
        preferred_partner_gender: preferred_gender,
        language: "de",
        terms_accepted: true,
        locations: [%{country_id: country_id, zip_code: zip_code}]
      }
      |> maybe_put(:search_radius, persona[:search_radius])
      |> maybe_put(:partner_height_min, persona[:partner_height_min])
      |> maybe_put(:partner_height_max, persona[:partner_height_max])
      |> maybe_put(:partner_minimum_age_offset, persona[:partner_minimum_age_offset])
      |> maybe_put(:partner_maximum_age_offset, persona[:partner_maximum_age_offset])

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        user =
          if Map.get(persona, :waitlisted, false) do
            confirm_only_user(user)
          else
            confirm_and_activate_user(user)
          end

        assign_roles(user, Map.get(persona, :roles, []))

        profile = Enum.at(content.personality_profiles, persona.profile)
        create_persona_avatar(user, gender, persona.avatar)
        assign_persona_traits(user, profile, lookup)
        update_persona_intro(user, index, content.persona_intros)
        create_persona_moodboard(user, persona, index, content)

        activity_pattern = persona[:activity] || auto_activity_pattern(index)
        seed_login_activity(user, activity_pattern, index)

        if persona[:blacklist], do: add_blacklist_entry(user, persona.blacklist)
        if persona[:conflict_trait], do: add_conflict_trait(user, persona.conflict_trait, lookup)

        state = if Map.get(persona, :waitlisted, false), do: " [waitlisted]", else: ""
        group = if persona[:group], do: " [#{persona.group}]", else: ""
        IO.puts("  Created: #{persona.name} #{persona.last_name} (#{email})#{state}#{group}")

        {:ok, user}

      {:error, reason} ->
        IO.puts("  ERROR: #{persona.name} #{persona.last_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ==========================================================================
  # AVATAR HELPERS
  # ==========================================================================
  defp create_persona_avatar(user, gender, avatar_stem) do
    avatar_dir = avatar_directory(gender)
    avatar_path = Path.join(avatar_dir, "avatar-dev-#{avatar_stem}.jpg")

    case Photos.upload_photo("User", user.id, avatar_path, type: "avatar") do
      {:ok, photo} ->
        Moodboard.link_avatar_to_pinned_item(user.id, photo.id)
        {:ok, photo}

      {:error, reason} ->
        IO.puts("    Warning: avatar failed for #{user.display_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp avatar_directory(gender) do
    Path.join([:code.priv_dir(:animina), "static", "images", "seeds", "avatars", gender])
  end

  # ==========================================================================
  # INTRO STORY (unique per persona)
  # ==========================================================================
  defp update_persona_intro(user, index, persona_intros) do
    case Map.get(persona_intros, index) do
      nil ->
        :ok

      intro ->
        case Moodboard.get_pinned_item(user.id) do
          nil -> :ok
          item -> if item.moodboard_story, do: Moodboard.update_story(item.moodboard_story, intro)
        end
    end
  end

  # ==========================================================================
  # MOODBOARD CREATION (topic-matched content, unique per persona)
  # ==========================================================================
  defp create_persona_moodboard(user, persona, seed_index, content) do
    # Seed PRNG with unique values per persona — uses both index AND name hash
    # to guarantee different seeds even for indices that differ by 60
    name_hash = :erlang.phash2({persona.name, persona.last_name})
    :rand.seed(:exsss, {seed_index * 7 + name_hash, seed_index * 11 + 1, seed_index * 13 + 1})

    # Gather photos from persona's topics
    photos =
      persona.topics
      |> Enum.flat_map(&Map.get(content.topic_photos, &1, []))
      |> Enum.uniq()
      |> Enum.shuffle()

    # Gather stories from persona's topics and shuffle with persona-unique PRNG
    stories =
      persona.topics
      |> Enum.flat_map(&Map.get(content.topic_stories, &1, []))
      |> Enum.uniq()
      |> Enum.shuffle()
      |> Enum.take(8)

    # 4-8 items per persona
    item_count = 4 + rem(seed_index, 5)
    photo_count = max(length(photos), 1)
    story_count = max(length(stories), 1)

    for i <- 0..(item_count - 1) do
      photo = Enum.at(photos, rem(i, photo_count))
      source_path = photo_source_path(photo)

      cond do
        # First half: combined photo + story
        i < div(item_count, 2) ->
          story = Enum.at(stories, rem(i, story_count))
          create_combined_moodboard_item(user, source_path, story)

        # Every 3rd remaining: text-only (occasionally a long story)
        rem(i, 3) == 0 ->
          story =
            if rem(seed_index + i, 6) == 0 do
              Enum.at(content.long_stories, rem(seed_index, length(content.long_stories)))
            else
              Enum.at(stories, rem(i, story_count))
            end

          create_story_moodboard_item(user, story)

        # Rest: photo-only
        true ->
          create_photo_moodboard_item(user, source_path)
      end

      Process.sleep(10)
    end
  end

  defp photo_source_path(filename) do
    Path.join([
      :code.priv_dir(:animina),
      "static",
      "images",
      "seeds",
      "lifestyle",
      filename
    ])
  end

  defp create_photo_moodboard_item(user, source_path) do
    case Moodboard.create_photo_item(user, source_path) do
      {:ok, item} -> {:ok, item}
      error -> error
    end
  end

  defp create_combined_moodboard_item(user, source_path, story) do
    case Moodboard.create_combined_item(user, source_path, story) do
      {:ok, item} -> {:ok, item}
      error -> error
    end
  end

  defp create_story_moodboard_item(user, story) do
    Moodboard.create_story_item(user, story)
  end

  # ==========================================================================
  # TRAIT ASSIGNMENT
  # ==========================================================================
  defp assign_persona_traits(user, profile, lookup) do
    # Ensure default published categories
    Traits.ensure_default_published_categories(user)

    # Assign profile traits
    assign_profile_traits(user, profile, lookup)

    # Always assign Deutsch as spoken language
    case get_in(lookup, ["Languages", "Deutsch"]) do
      nil -> :ok
      flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "white", intensity: "hard", position: 1})
    end
  end

  defp build_flag_lookup do
    for category <- Traits.list_categories(), into: %{} do
      flags = Traits.list_flags_by_category(category)
      flag_map = for f <- flags, into: %{}, do: {f.name, f}
      {category.name, flag_map}
    end
  end

  defp assign_profile_traits(user, profile, lookup) do
    # Collect all category names used across white/green/red
    all_category_names =
      [Map.keys(profile.white), Map.keys(profile.green), Map.keys(profile.red)]
      |> List.flatten()
      |> Enum.uniq()

    # Ensure opt-in records exist for non-core categories
    optin_by_name =
      for c <- Traits.list_optin_categories(), into: %{}, do: {c.name, c.id}

    for category_name <- all_category_names,
        category_id = Map.get(optin_by_name, category_name),
        category_id != nil do
      Animina.Traits.UserCategoryOptIn.changeset(
        %Animina.Traits.UserCategoryOptIn{},
        %{user_id: user.id, category_id: category_id}
      )
      |> Repo.insert(on_conflict: :nothing)
    end

    # Assign white flags
    for {category_name, flag_names} <- profile.white do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> IO.puts("    Warning: flag '#{flag_name}' not found in '#{category_name}'")
          flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "white", intensity: "hard", position: pos})
        end
      end
    end

    # Assign green flags
    for {category_name, flag_names} <- profile.green do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> :ok
          flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "green", intensity: "hard", position: pos})
        end
      end
    end

    # Assign red flags
    for {category_name, flag_names} <- profile.red do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> :ok
          flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "red", intensity: "hard", position: pos})
        end
      end
    end
  end

  # ==========================================================================
  # LOGIN ACTIVITY SEEDING (for heatmap display)
  # ==========================================================================

  @activity_patterns [:daily_active, :evening_regular, :morning_routine, :weekend_warrior, :sporadic, :new_user, :fading]

  defp auto_activity_pattern(index) do
    Enum.at(@activity_patterns, rem(index, length(@activity_patterns)))
  end

  defp seed_login_activity(user, pattern, seed_index) do
    :rand.seed(:exsss, {seed_index * 31, seed_index * 37, seed_index * 41})
    today = Date.utc_today()

    days =
      case pattern do
        :new_user -> generate_new_user_days(today)
        :fading -> generate_fading_days(today)
        other -> generate_pattern_days(today, other)
      end

    entries =
      Enum.flat_map(days, fn {date, count} ->
        for _ <- 1..count do
          hour = Enum.random(6..23)
          minute = Enum.random(0..59)
          {:ok, dt} = DateTime.new(date, Time.new!(hour, minute, 0), "Etc/UTC")
          event = Enum.random(["login_email", "login_passkey"])

          %{
            id: Ecto.UUID.generate(),
            actor_id: user.id,
            category: "auth",
            event: event,
            summary: "#{user.display_name} logged in",
            metadata: %{},
            inserted_at: DateTime.truncate(dt, :second)
          }
        end
      end)

    # Bulk insert in chunks of 500
    Enum.chunk_every(entries, 500)
    |> Enum.each(fn chunk ->
      Repo.insert_all(ActivityLogEntry, chunk)
    end)
  end

  # Last 120 days, pattern-based
  defp generate_pattern_days(today, pattern) do
    for offset <- 0..120,
        date = Date.add(today, -offset),
        count = day_login_count(date, pattern),
        count > 0 do
      {date, count}
    end
  end

  # New user: only last ~14 days, active daily
  defp generate_new_user_days(today) do
    for offset <- 0..14,
        date = Date.add(today, -offset),
        count = Enum.random(1..3),
        :rand.uniform() < 0.85 do
      {date, count}
    end
  end

  # Fading user: active 60-120 days ago, tapers off, almost nothing recent
  defp generate_fading_days(today) do
    for offset <- 0..120,
        date = Date.add(today, -offset),
        count = fading_count(offset),
        count > 0 do
      {date, count}
    end
  end

  defp fading_count(offset) do
    cond do
      offset < 14 -> if :rand.uniform() < 0.05, do: 1, else: 0
      offset < 30 -> if :rand.uniform() < 0.15, do: 1, else: 0
      offset < 60 -> if :rand.uniform() < 0.5, do: Enum.random(1..2), else: 0
      true -> if :rand.uniform() < 0.75, do: Enum.random(1..3), else: 0
    end
  end

  defp day_login_count(date, pattern) do
    dow = Date.day_of_week(date)
    weekend? = dow in [6, 7]

    case pattern do
      :daily_active ->
        if :rand.uniform() < 0.9, do: Enum.random(1..4), else: 0

      :evening_regular ->
        if weekend? do
          if :rand.uniform() < 0.3, do: 1, else: 0
        else
          if :rand.uniform() < 0.8, do: Enum.random(1..2), else: 0
        end

      :morning_routine ->
        if :rand.uniform() < 0.7, do: 1, else: 0

      :weekend_warrior ->
        if weekend? do
          Enum.random(1..3)
        else
          if :rand.uniform() < 0.1, do: 1, else: 0
        end

      :sporadic ->
        if :rand.uniform() < 0.12, do: Enum.random(1..2), else: 0
    end
  end

  # ==========================================================================
  # SHARED HELPERS
  # ==========================================================================
  defp birthday_from_age(age) do
    today = Date.utc_today()
    Date.add(today, -(age * 365 + Enum.random(0..364)))
  end

  defp generate_phone(index) do
    prefixes = ["150", "151", "152", "153", "155", "156", "157", "159", "160", "162", "163", "172", "176", "177", "178", "179"]
    prefix = Enum.at(prefixes, rem(index, length(prefixes)))
    suffix = String.pad_leading("#{10000000 + index}", 8, "0")
    "+49#{prefix}#{suffix}"
  end

  defp confirm_and_activate_user(user) do
    now = DateTime.utc_now(:second)

    {1, _} =
      Repo.update_all(
        from(u in Animina.Accounts.User, where: u.id == ^user.id),
        set: [confirmed_at: now, state: "normal"]
      )

    Repo.get!(Animina.Accounts.User, user.id)
  end

  defp confirm_only_user(user) do
    now = DateTime.utc_now(:second)
    end_waitlist_at = DateTime.add(now, 14 * 86_400, :second)

    {1, _} =
      Repo.update_all(
        from(u in Animina.Accounts.User, where: u.id == ^user.id),
        set: [confirmed_at: now, end_waitlist_at: end_waitlist_at]
      )

    Repo.get!(Animina.Accounts.User, user.id)
  end

  defp assign_roles(user, roles) do
    for role <- roles do
      Accounts.assign_role(user, to_string(role))
    end
  end

  defp email_slug(name) do
    name
    |> String.downcase()
    |> String.replace("ä", "ae")
    |> String.replace("ö", "oe")
    |> String.replace("ü", "ue")
    |> String.replace("ß", "ss")
    |> String.replace("ç", "c")
    |> String.replace(~r/[^a-z0-9]/, "")
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp add_blacklist_entry(user, value) do
    case ContactBlacklist.add_entry(user, %{value: value}) do
      {:ok, _} -> :ok
      {:error, reason} -> IO.puts("    Warning: blacklist entry failed: #{inspect(reason)}")
    end
  end

  defp add_conflict_trait(user, {color, category_name, flag_name}, lookup) do
    case get_in(lookup, [category_name, flag_name]) do
      nil ->
        IO.puts("    Warning: flag '#{flag_name}' not found in '#{category_name}'")

      flag ->
        ensure_category_optin(user, category_name)

        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: to_string(color),
          intensity: "hard",
          position: 1
        })
    end
  end

  defp ensure_category_optin(user, category_name) do
    optin_names =
      for c <- Traits.list_optin_categories(), into: %{}, do: {c.name, c.id}

    case Map.get(optin_names, category_name) do
      nil ->
        :ok

      category_id ->
        Animina.Traits.UserCategoryOptIn.changeset(
          %Animina.Traits.UserCategoryOptIn{},
          %{user_id: user.id, category_id: category_id}
        )
        |> Repo.insert(on_conflict: :nothing)
    end
  end
end
