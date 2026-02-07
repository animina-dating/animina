defmodule Animina.FeatureFlags do
  @moduledoc """
  Context for managing feature flags.

  Wraps FunWithFlags with additional settings for:
  - Auto-approve mode: skip check and return a predefined value
  - Artificial delays: for UX testing
  - Flag metadata: descriptions and groupings

  ## Usage

      # Check if a feature should run
      case FeatureFlags.check_status(:photo_nsfw_check, false) do
        :run -> do_nsfw_check(photo)
        {:skip, value} -> skip_with_value(photo, value)
        :skip -> skip_check(photo)
      end

      # Apply configured delay
      FeatureFlags.apply_delay(:photo_nsfw_check)

      # Simple boolean check
      FeatureFlags.nsfw_check_enabled?()
  """

  require Logger

  import Ecto.Query

  alias Animina.FeatureFlags.FlagSetting
  alias Animina.Repo

  @photo_flags [
    %{
      name: :photo_blacklist_check,
      label: "Blacklist Check",
      description: "Check photos against dhash blacklist",
      default_auto_approve_value: nil
    }
  ]

  @ollama_settings [
    %{
      name: :photo_ollama_check,
      label: "Ollama Photo Check",
      description: "Photo classification using Ollama vision model",
      type: :flag,
      default_auto_approve_value: true
    },
    %{
      name: :ollama_model,
      label: "Ollama Model",
      description: "Vision model used for photo classification (e.g., qwen3-vl:4b, llava:13b)",
      type: :string,
      default_value: "qwen3-vl:8b"
    },
    %{
      name: :ollama_debug_max_entries,
      label: "Ollama Debug Max Entries",
      description: "Maximum number of Ollama debug entries to store and display",
      type: :integer,
      default_value: 100,
      min_value: 10,
      max_value: 1000
    },
    %{
      name: :ollama_debug_display,
      label: "Ollama Debug Display",
      description:
        "Show Ollama API calls at the bottom of pages for admins (useful for debugging)",
      type: :flag
    }
  ]

  @system_settings [
    %{
      name: :referral_threshold,
      label: "Referral Threshold",
      description: "Number of confirmed referrals needed to auto-activate waitlisted users",
      type: :integer,
      default_value: 3,
      min_value: 1,
      max_value: 100
    },
    %{
      name: :soft_delete_grace_days,
      label: "Soft Delete Grace Period",
      description: "Number of days before soft-deleted accounts are permanently removed",
      type: :integer,
      default_value: 28,
      min_value: 1,
      max_value: 365
    }
  ]

  @admin_flags [
    %{
      name: :admin_view_moodboards,
      label: "Admin View Moodboards",
      description: "Allow admins to view any user's moodboard (for moderation purposes)"
    }
  ]

  @discovery_settings [
    # General settings
    %{
      name: :discovery_suggestions_per_list,
      label: "Suggestions Per List",
      description: "Number of partner suggestions per list (Combined, Safe, Attracted)",
      type: :integer,
      default_value: 8,
      min_value: 1,
      max_value: 50
    },
    %{
      name: :discovery_cooldown_days,
      label: "Cooldown Days",
      description: "Days before a user can reappear in suggestions",
      type: :integer,
      default_value: 30,
      min_value: 1,
      max_value: 365
    },
    %{
      name: :discovery_new_user_boost_days,
      label: "New User Boost Days",
      description: "Days during which new users get a score boost",
      type: :integer,
      default_value: 14,
      min_value: 1,
      max_value: 90
    },
    %{
      name: :discovery_default_search_radius,
      label: "Default Search Radius (km)",
      description: "Default search radius in km if user hasn't set one",
      type: :integer,
      default_value: 60,
      min_value: 10,
      max_value: 500
    },
    # Scoring weights
    %{
      name: :discovery_soft_red_penalty,
      label: "Soft Red Penalty",
      description: "Score penalty per soft-red flag match (negative)",
      type: :integer,
      default_value: -50,
      min_value: -200,
      max_value: 0
    },
    %{
      name: :discovery_green_hard_bonus,
      label: "Green Hard Bonus",
      description: "Score bonus per hard green-white flag match",
      type: :integer,
      default_value: 20,
      min_value: 1,
      max_value: 100
    },
    %{
      name: :discovery_green_soft_bonus,
      label: "Green Soft Bonus",
      description: "Score bonus per soft green-white flag match",
      type: :integer,
      default_value: 10,
      min_value: 1,
      max_value: 50
    },
    %{
      name: :discovery_white_white_bonus,
      label: "White-White Bonus",
      description: "Score bonus per shared white trait",
      type: :integer,
      default_value: 5,
      min_value: 1,
      max_value: 25
    },
    %{
      name: :discovery_new_user_boost,
      label: "New User Score Boost",
      description: "Score boost for users registered within boost period",
      type: :integer,
      default_value: 100,
      min_value: 0,
      max_value: 500
    },
    %{
      name: :discovery_incomplete_penalty,
      label: "Incomplete Profile Penalty",
      description: "Score penalty for profiles missing photo/height/gender",
      type: :integer,
      default_value: -30,
      min_value: -200,
      max_value: 0
    },
    # Category multipliers
    %{
      name: :discovery_category_multiplier_languages,
      label: "Languages Category Multiplier",
      description: "Score multiplier for Language category matches",
      type: :integer,
      default_value: 3,
      min_value: 1,
      max_value: 10
    },
    %{
      name: :discovery_category_multiplier_relationship_goals,
      label: "Relationship Goals Multiplier",
      description: "Score multiplier for 'What I'm Looking For' category matches",
      type: :integer,
      default_value: 2,
      min_value: 1,
      max_value: 10
    },
    %{
      name: :discovery_category_default_multiplier,
      label: "Default Category Multiplier",
      description: "Default score multiplier for other categories",
      type: :integer,
      default_value: 1,
      min_value: 1,
      max_value: 10
    },
    # Algorithm selection
    %{
      name: :discovery_scorer_module,
      label: "Scorer Algorithm",
      description: "Scoring algorithm: 'weighted' (default) or 'simple'",
      type: :string,
      default_value: "weighted"
    },
    %{
      name: :discovery_filter_module,
      label: "Filter Strategy",
      description: "Filter strategy: 'standard' (default) or 'relaxed'",
      type: :string,
      default_value: "standard"
    },
    # Filter options
    %{
      name: :discovery_exclude_incomplete_profiles,
      label: "Exclude Incomplete Profiles",
      description: "If true, fully exclude profiles missing photo/height/gender",
      type: :flag
    },
    %{
      name: :discovery_require_mutual_bookmark_exclusion,
      label: "Exclude Mutually Bookmarked",
      description: "Exclude users who have mutually bookmarked each other",
      type: :flag,
      default_enabled: true
    },
    # Wildcard settings
    %{
      name: :discovery_wildcard_count,
      label: "Wildcard Count",
      description: "Number of random wildcard profiles shown on the discover page",
      type: :integer,
      default_value: 2,
      min_value: 0,
      max_value: 10
    },
    # Chat slot settings
    %{
      name: :chat_max_active_slots,
      label: "Max Active Chat Slots",
      description: "Maximum number of active conversations a user can have at once",
      type: :integer,
      default_value: 6,
      min_value: 1,
      max_value: 20
    },
    %{
      name: :chat_daily_new_limit,
      label: "Daily New Chat Limit",
      description: "Maximum number of new conversations a user can start per day",
      type: :integer,
      default_value: 2,
      min_value: 1,
      max_value: 10
    },
    %{
      name: :chat_love_emergency_cost,
      label: "Love Emergency Cost",
      description: "Number of conversations that must be closed to reopen one via Love Emergency",
      type: :integer,
      default_value: 4,
      min_value: 1,
      max_value: 10
    },
    %{
      name: :discovery_daily_set_size,
      label: "Daily Discovery Set Size",
      description: "Number of scored suggestions shown per day on the discover page",
      type: :integer,
      default_value: 6,
      min_value: 1,
      max_value: 20
    },
    # Popularity protection settings
    %{
      name: :discovery_popularity_enabled,
      label: "Popular User Protection",
      description: "Enable daily inquiry limits and popularity scoring adjustments",
      type: :flag
    },
    %{
      name: :discovery_daily_inquiry_limit,
      label: "Daily Inquiry Limit",
      description: "Max inquiries per day before temporary removal from discovery",
      type: :integer,
      default_value: 6,
      min_value: 1,
      max_value: 50
    },
    %{
      name: :discovery_popularity_score_bonus,
      label: "Low Popularity Bonus",
      description: "Score bonus for users with low popularity (increases visibility)",
      type: :integer,
      default_value: 10,
      min_value: 0,
      max_value: 100
    },
    %{
      name: :discovery_popularity_score_penalty,
      label: "High Popularity Penalty",
      description: "Score penalty for highly popular users (balances exposure)",
      type: :integer,
      default_value: -15,
      min_value: -100,
      max_value: 0
    }
  ]

  # --- Flag Settings CRUD ---

  @doc """
  Creates a new flag setting.
  """
  def create_flag_setting(attrs) do
    %FlagSetting{}
    |> FlagSetting.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a flag setting by flag name.
  """
  def get_flag_setting(flag_name) when is_atom(flag_name) do
    get_flag_setting(Atom.to_string(flag_name))
  end

  def get_flag_setting(flag_name) when is_binary(flag_name) do
    FlagSetting
    |> where([s], s.flag_name == ^flag_name)
    |> Repo.one()
  end

  @doc """
  Gets a flag setting by ID.
  """
  def get_flag_setting_by_id(id) do
    Repo.get(FlagSetting, id)
  end

  @doc """
  Updates a flag setting.
  """
  def update_flag_setting(%FlagSetting{} = setting, attrs) do
    setting
    |> FlagSetting.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets or creates a flag setting.
  """
  def get_or_create_flag_setting(flag_name, default_attrs \\ %{}) do
    case get_flag_setting(flag_name) do
      nil ->
        attrs = Map.merge(default_attrs, %{flag_name: to_string(flag_name)})
        create_flag_setting(attrs)

      setting ->
        {:ok, setting}
    end
  end

  @doc """
  Lists all flag settings.
  """
  def list_flag_settings do
    FlagSetting
    |> order_by([s], asc: s.flag_name)
    |> Repo.all()
  end

  # --- FunWithFlags Wrappers ---

  @doc """
  Enables a feature flag.
  """
  def enable(flag_name) do
    FunWithFlags.enable(flag_name)
  end

  @doc """
  Disables a feature flag.
  """
  def disable(flag_name) do
    FunWithFlags.disable(flag_name)
  end

  @doc """
  Checks if a feature flag is enabled.
  """
  def enabled?(flag_name) do
    FunWithFlags.enabled?(flag_name)
  end

  # --- Status Checks ---

  @doc """
  Checks the status of a feature flag and returns how to proceed.

  Returns:
  - `:run` - The feature is enabled, run the check normally
  - `{:skip, value}` - The feature is disabled with auto-approve, use this value
  - `:skip` - The feature is disabled without auto-approve, skip entirely

  The `default_value` is used when auto-approve is enabled but no explicit
  auto_approve_value is configured.
  """
  def check_status(flag_name, default_value) do
    if enabled?(flag_name) do
      :run
    else
      check_auto_approve_status(flag_name, default_value)
    end
  end

  defp check_auto_approve_status(flag_name, default_value) do
    case get_flag_setting(flag_name) do
      %FlagSetting{settings: settings} when is_map(settings) ->
        if get_setting(settings, :auto_approve) do
          value = get_setting(settings, :auto_approve_value, default_value)
          {:skip, value}
        else
          :skip
        end

      _ ->
        :skip
    end
  end

  # Helper to get setting value regardless of whether keys are atoms or strings
  defp get_setting(settings, key, default \\ nil) do
    Map.get(settings, key) || Map.get(settings, to_string(key)) || default
  end

  @doc """
  Applies the configured delay for a feature flag.
  Does nothing if no delay is configured or the flag doesn't exist.
  """
  def apply_delay(flag_name) do
    case get_flag_setting(flag_name) do
      %FlagSetting{settings: settings} when is_map(settings) ->
        delay_ms = get_setting(settings, :delay_ms, 0)
        if delay_ms > 0, do: Process.sleep(delay_ms)

      _ ->
        :ok
    end
  end

  # --- Photo Processing Convenience Functions ---

  @doc """
  Returns whether Ollama photo check is enabled.
  """
  def ollama_check_enabled? do
    enabled?(:photo_ollama_check)
  end

  @doc """
  Returns whether blacklist check is enabled.
  """
  def blacklist_check_enabled? do
    enabled?(:photo_blacklist_check)
  end

  @doc """
  Returns whether Ollama debug display is enabled.
  When enabled, admins can see Ollama API calls at the bottom of pages.
  """
  def ollama_debug_enabled? do
    enabled?(:ollama_debug_display)
  end

  @doc """
  Returns whether admins can view any user's moodboard.
  Disabled by default for privacy.
  """
  def admin_can_view_moodboards? do
    enabled?(:admin_view_moodboards)
  end

  # --- Photo Flags Listing ---

  @doc """
  Returns the list of photo processing flag definitions.
  """
  def photo_flag_definitions do
    @photo_flags
  end

  @doc """
  Returns all photo processing flags with their current states and settings.
  """
  def get_all_photo_flags do
    Enum.map(@photo_flags, fn flag_def ->
      setting = get_flag_setting(flag_def.name)

      %{
        name: flag_def.name,
        label: flag_def.label,
        description: flag_def.description,
        default_auto_approve_value: flag_def.default_auto_approve_value,
        enabled: enabled?(flag_def.name),
        setting: setting
      }
    end)
  end

  @doc """
  Initializes default flag states for photo processing.
  Called during application startup. Enables all flags by default for safety.
  """
  def initialize_photo_flags do
    Enum.each(@photo_flags, fn flag_def ->
      # Enable flag if not already set (preserves existing settings)
      unless FunWithFlags.enabled?(flag_def.name) do
        FunWithFlags.enable(flag_def.name)
        Logger.info("Feature flag #{flag_def.name} enabled by default")
      end

      # Create default settings if they don't exist
      get_or_create_flag_setting(flag_def.name, %{
        description: flag_def.description,
        settings: %{
          auto_approve: false,
          auto_approve_value: flag_def.default_auto_approve_value,
          delay_ms: 0
        }
      })
    end)
  end

  # --- Ollama Settings ---

  @doc """
  Returns the list of ollama setting definitions.
  """
  def ollama_settings_definitions do
    @ollama_settings
  end

  @doc """
  Returns all ollama settings with their current states and values.
  """
  def get_all_ollama_settings do
    Enum.map(@ollama_settings, fn setting_def ->
      case setting_def.type do
        :flag ->
          flag_setting = get_flag_setting(setting_def.name)

          %{
            name: setting_def.name,
            label: setting_def.label,
            description: setting_def.description,
            type: :flag,
            enabled: enabled?(setting_def.name),
            setting: flag_setting,
            default_auto_approve_value: Map.get(setting_def, :default_auto_approve_value)
          }

        :string ->
          %{
            name: setting_def.name,
            label: setting_def.label,
            description: setting_def.description,
            type: :string,
            current_value: get_system_setting_value(setting_def.name, setting_def.default_value),
            default_value: setting_def.default_value
          }

        :integer ->
          %{
            name: setting_def.name,
            label: setting_def.label,
            description: setting_def.description,
            type: :integer,
            current_value: get_system_setting_value(setting_def.name, setting_def.default_value),
            default_value: setting_def.default_value,
            min_value: setting_def.min_value,
            max_value: setting_def.max_value
          }
      end
    end)
  end

  @doc """
  Initializes default ollama settings.
  Called during application startup. Flags are disabled by default.
  """
  def initialize_ollama_settings do
    Enum.each(@ollama_settings, &initialize_ollama_setting/1)
  end

  defp initialize_ollama_setting(%{type: :flag} = setting_def) do
    maybe_enable_flag(setting_def.name)

    get_or_create_flag_setting(setting_def.name, %{
      description: setting_def.description,
      settings: %{
        auto_approve: false,
        auto_approve_value: Map.get(setting_def, :default_auto_approve_value),
        delay_ms: 0
      }
    })
  end

  defp initialize_ollama_setting(setting_def) do
    flag_name = "system:#{setting_def.name}"

    get_or_create_flag_setting(flag_name, %{
      description: setting_def.description,
      settings: %{value: setting_def.default_value}
    })
  end

  defp maybe_enable_flag(flag_name) do
    unless FunWithFlags.enabled?(flag_name) do
      FunWithFlags.enable(flag_name)
      Logger.info("Feature flag #{flag_name} enabled by default")
    end
  end

  # --- Admin Flags ---

  @doc """
  Returns the list of admin flag definitions.
  """
  def admin_flag_definitions do
    @admin_flags
  end

  @doc """
  Returns all admin flags with their current states.
  """
  def get_all_admin_flags do
    Enum.map(@admin_flags, fn flag_def ->
      %{
        name: flag_def.name,
        label: flag_def.label,
        description: flag_def.description,
        enabled: enabled?(flag_def.name)
      }
    end)
  end

  @doc """
  Initializes default admin flag states.
  Called during application startup. Admin flags are disabled by default.
  """
  def initialize_admin_flags do
    Enum.each(@admin_flags, fn flag_def ->
      # Create default settings if they don't exist
      get_or_create_flag_setting(flag_def.name, %{
        description: flag_def.description,
        settings: %{}
      })
    end)
  end

  # --- System Settings ---

  @doc """
  Returns the list of system setting definitions.
  """
  def system_setting_definitions do
    @system_settings
  end

  @doc """
  Returns all system settings with their current values.
  """
  def get_all_system_settings do
    Enum.map(@system_settings, fn setting_def ->
      Map.put(
        setting_def,
        :current_value,
        get_system_setting_value(setting_def.name, setting_def.default_value)
      )
    end)
  end

  @doc """
  Gets the current value for a system setting.
  Returns the default value if not configured.
  """
  def get_system_setting_value(name, default) do
    flag_name = "system:#{name}"

    case get_flag_setting(flag_name) do
      %FlagSetting{settings: settings} when is_map(settings) ->
        value = Map.get(settings, "value") || Map.get(settings, :value)
        if is_nil(value) || value == "", do: default, else: value

      _ ->
        default
    end
  end

  @doc """
  Initializes default system settings.
  Called during application startup.
  """
  def initialize_system_settings do
    Enum.each(@system_settings, fn setting_def ->
      flag_name = "system:#{setting_def.name}"

      # Create default settings if they don't exist
      get_or_create_flag_setting(flag_name, %{
        description: setting_def.description,
        settings: %{value: setting_def.default_value}
      })
    end)
  end

  # --- System Settings Convenience Functions ---

  @doc """
  Returns the configured referral threshold.
  Default: 3
  """
  def referral_threshold do
    get_system_setting_value(:referral_threshold, 3)
  end

  @doc """
  Returns the configured soft delete grace period in days.
  Default: 28
  """
  def soft_delete_grace_days do
    get_system_setting_value(:soft_delete_grace_days, 28)
  end

  @doc """
  Returns the configured Ollama model for photo classification.
  Default: "qwen3-vl:8b"
  """
  def ollama_model do
    get_system_setting_value(:ollama_model, "qwen3-vl:8b")
  end

  @doc """
  Returns the configured maximum number of Ollama debug entries to store.
  Default: 100
  """
  def ollama_debug_max_entries do
    get_system_setting_value(:ollama_debug_max_entries, 100)
  end

  # --- Discovery Settings ---

  @doc """
  Returns the list of discovery setting definitions.
  """
  def discovery_settings_definitions do
    @discovery_settings
  end

  @doc """
  Returns all discovery settings with their current values.
  """
  def get_all_discovery_settings do
    Enum.map(@discovery_settings, fn setting_def ->
      case setting_def.type do
        :flag ->
          %{
            name: setting_def.name,
            label: setting_def.label,
            description: setting_def.description,
            type: :flag,
            enabled: enabled?(setting_def.name),
            default_enabled: Map.get(setting_def, :default_enabled, false)
          }

        :integer ->
          %{
            name: setting_def.name,
            label: setting_def.label,
            description: setting_def.description,
            type: :integer,
            current_value: get_system_setting_value(setting_def.name, setting_def.default_value),
            default_value: setting_def.default_value,
            min_value: setting_def[:min_value],
            max_value: setting_def[:max_value]
          }

        :string ->
          %{
            name: setting_def.name,
            label: setting_def.label,
            description: setting_def.description,
            type: :string,
            current_value: get_system_setting_value(setting_def.name, setting_def.default_value),
            default_value: setting_def.default_value
          }
      end
    end)
  end

  @doc """
  Initializes default discovery settings.
  Called during application startup.
  """
  def initialize_discovery_settings do
    Enum.each(@discovery_settings, &initialize_discovery_setting/1)
  end

  defp initialize_discovery_setting(%{type: :flag} = setting_def) do
    if Map.get(setting_def, :default_enabled, false) do
      maybe_enable_flag(setting_def.name)
    end

    get_or_create_flag_setting(setting_def.name, %{
      description: setting_def.description,
      settings: %{}
    })
  end

  defp initialize_discovery_setting(setting_def) do
    flag_name = "system:#{setting_def.name}"

    get_or_create_flag_setting(flag_name, %{
      description: setting_def.description,
      settings: %{value: setting_def.default_value}
    })
  end

  # --- Discovery Settings Convenience Functions ---

  @doc """
  Returns the configured number of suggestions per list.
  Default: 8
  """
  def discovery_suggestions_per_list do
    get_system_setting_value(:discovery_suggestions_per_list, 8)
  end

  @doc """
  Returns the configured cooldown period in days.
  Default: 30
  """
  def discovery_cooldown_days do
    get_system_setting_value(:discovery_cooldown_days, 30)
  end

  @doc """
  Returns the configured new user boost period in days.
  Default: 14
  """
  def discovery_new_user_boost_days do
    get_system_setting_value(:discovery_new_user_boost_days, 14)
  end

  @doc """
  Returns the configured default search radius in km.
  Default: 60
  """
  def discovery_default_search_radius do
    get_system_setting_value(:discovery_default_search_radius, 60)
  end

  @doc """
  Returns the configured soft red penalty score.
  Default: -50
  """
  def discovery_soft_red_penalty do
    get_system_setting_value(:discovery_soft_red_penalty, -50)
  end

  @doc """
  Returns the configured green hard bonus score.
  Default: 20
  """
  def discovery_green_hard_bonus do
    get_system_setting_value(:discovery_green_hard_bonus, 20)
  end

  @doc """
  Returns the configured green soft bonus score.
  Default: 10
  """
  def discovery_green_soft_bonus do
    get_system_setting_value(:discovery_green_soft_bonus, 10)
  end

  @doc """
  Returns the configured white-white bonus score.
  Default: 5
  """
  def discovery_white_white_bonus do
    get_system_setting_value(:discovery_white_white_bonus, 5)
  end

  @doc """
  Returns the configured new user score boost.
  Default: 100
  """
  def discovery_new_user_boost do
    get_system_setting_value(:discovery_new_user_boost, 100)
  end

  @doc """
  Returns the configured incomplete profile penalty.
  Default: -30
  """
  def discovery_incomplete_penalty do
    get_system_setting_value(:discovery_incomplete_penalty, -30)
  end

  @doc """
  Returns the configured number of wildcard profiles to show.
  Default: 2
  """
  def discovery_wildcard_count do
    get_system_setting_value(:discovery_wildcard_count, 2)
  end

  @doc """
  Returns the category multiplier for a given category name.
  """
  def discovery_category_multiplier(category_name) do
    case category_name do
      "Languages" ->
        get_system_setting_value(:discovery_category_multiplier_languages, 3)

      "What I'm Looking For" ->
        get_system_setting_value(:discovery_category_multiplier_relationship_goals, 2)

      _ ->
        get_system_setting_value(:discovery_category_default_multiplier, 1)
    end
  end

  @doc """
  Returns the configured scorer module name.
  Default: "weighted"
  """
  def discovery_scorer_module do
    get_system_setting_value(:discovery_scorer_module, "weighted")
  end

  @doc """
  Returns the configured filter module name.
  Default: "standard"
  """
  def discovery_filter_module do
    get_system_setting_value(:discovery_filter_module, "standard")
  end

  @doc """
  Returns whether incomplete profiles should be fully excluded.
  Default: false
  """
  def discovery_exclude_incomplete_profiles? do
    enabled?(:discovery_exclude_incomplete_profiles)
  end

  @doc """
  Returns whether mutually bookmarked users should be excluded.
  Default: true
  """
  def discovery_require_mutual_bookmark_exclusion? do
    enabled?(:discovery_require_mutual_bookmark_exclusion)
  end

  # --- Popularity Protection Settings ---

  @doc """
  Returns whether popular user protection is enabled.
  Default: false
  """
  def discovery_popularity_enabled? do
    enabled?(:discovery_popularity_enabled)
  end

  @doc """
  Returns the configured daily inquiry limit.
  Default: 6
  """
  def discovery_daily_inquiry_limit do
    get_system_setting_value(:discovery_daily_inquiry_limit, 6)
  end

  @doc """
  Returns the configured score bonus for low-popularity users.
  Default: 10
  """
  def discovery_popularity_score_bonus do
    get_system_setting_value(:discovery_popularity_score_bonus, 10)
  end

  @doc """
  Returns the configured score penalty for high-popularity users.
  Default: -15
  """
  def discovery_popularity_score_penalty do
    get_system_setting_value(:discovery_popularity_score_penalty, -15)
  end

  # --- Chat Slot Settings ---

  @doc """
  Returns the maximum number of active conversations a user can have.
  Default: 6
  """
  def chat_max_active_slots do
    get_system_setting_value(:chat_max_active_slots, 6)
  end

  @doc """
  Returns the maximum number of new conversations a user can start per day.
  Default: 2
  """
  def chat_daily_new_limit do
    get_system_setting_value(:chat_daily_new_limit, 2)
  end

  @doc """
  Returns the number of conversations that must be closed to reopen one via Love Emergency.
  Default: 4
  """
  def chat_love_emergency_cost do
    get_system_setting_value(:chat_love_emergency_cost, 4)
  end

  @doc """
  Returns the number of scored suggestions shown per day on the discover page.
  Default: 6
  """
  def discovery_daily_set_size do
    get_system_setting_value(:discovery_daily_set_size, 6)
  end
end
