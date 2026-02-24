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

  @ollama_settings [
    %{
      name: :photo_ollama_check,
      label: "Ollama Photo Check",
      description: "Photo classification using Ollama vision model",
      type: :flag,
      default_auto_approve_value: true
    },
    # Adaptive model settings
    %{
      name: :ollama_adaptive_model,
      label: "Adaptive Model Selection",
      description:
        "Automatically step down to smaller models under queue pressure (8b → 4b → 2b)",
      type: :flag
    },
    # Spellcheck settings
    %{
      name: :spellcheck,
      label: "Spell Check",
      description: "LLM-powered spelling and grammar check for chat messages",
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
    },
    %{
      name: :waitlist_duration_days,
      label: "Waitlist Duration",
      description: "Default number of days new users spend on the waitlist",
      type: :integer,
      default_value: 14,
      min_value: 1,
      max_value: 365
    },
    %{
      name: :support_email,
      label: "Support Email",
      description:
        "Email address used as the sender for all outgoing emails and shown as contact in notification emails",
      type: :string,
      default_value: "sw@wintermeyer-consulting.de"
    },
    %{
      name: :pin_validity_minutes,
      label: "PIN Validity Minutes",
      description:
        "Minutes a registration confirmation PIN stays valid before the account is auto-deleted",
      type: :integer,
      default_value: 60,
      min_value: 5,
      max_value: 1440
    },
    %{
      name: :photo_max_upload_size_mb,
      label: "Photo Max Upload Size (MB)",
      description: "Maximum file size for photo uploads in megabytes",
      type: :integer,
      default_value: 10,
      min_value: 1,
      max_value: 50
    },
    %{
      name: :contact_blacklist_max_entries,
      label: "Contact Blacklist Max Entries",
      description: "Maximum number of blocked phone/email entries per user",
      type: :integer,
      default_value: 500,
      min_value: 10,
      max_value: 5000
    },
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
      name: :max_white_flags,
      label: "Max White Flags",
      description: "Maximum number of white (About Me) flags a user can select",
      type: :integer,
      default_value: 16,
      min_value: 1,
      max_value: 50
    },
    %{
      name: :max_green_flags,
      label: "Max Green Flags",
      description: "Maximum number of green (Partner Likes) flags a user can select",
      type: :integer,
      default_value: 10,
      min_value: 1,
      max_value: 50
    },
    %{
      name: :max_red_flags,
      label: "Max Red Flags",
      description: "Maximum number of red (Deal Breaker) flags a user can select",
      type: :integer,
      default_value: 10,
      min_value: 1,
      max_value: 50
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
  Returns the configured waitlist duration in days.
  Default: 14
  """
  def waitlist_duration_days do
    get_system_setting_value(:waitlist_duration_days, 14)
  end

  @doc """
  Returns the configured support email address.
  Default: "sw@wintermeyer-consulting.de"
  """
  def support_email do
    get_system_setting_value(:support_email, "sw@wintermeyer-consulting.de")
  end

  @doc """
  Returns the configured PIN validity duration in minutes.
  Default: 60
  """
  def pin_validity_minutes do
    get_system_setting_value(:pin_validity_minutes, 60)
  end

  @doc """
  Returns the configured maximum photo upload size in megabytes.
  Default: 10
  """
  def photo_max_upload_size_mb do
    get_system_setting_value(:photo_max_upload_size_mb, 10)
  end

  @doc """
  Returns the configured maximum number of contact blacklist entries per user.
  Default: 500
  """
  def contact_blacklist_max_entries do
    get_system_setting_value(:contact_blacklist_max_entries, 500)
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

  # --- Flag Limit Settings ---

  @doc """
  Returns the maximum number of white flags a user can select.
  Default: 16
  """
  def max_white_flags do
    get_system_setting_value(:max_white_flags, 16)
  end

  @doc """
  Returns the maximum number of green flags a user can select.
  Default: 10
  """
  def max_green_flags do
    get_system_setting_value(:max_green_flags, 10)
  end

  @doc """
  Returns the maximum number of red flags a user can select.
  Default: 10
  """
  def max_red_flags do
    get_system_setting_value(:max_red_flags, 10)
  end

  # --- Wingman Settings ---

  @doc """
  Returns whether the Wingman AI coaching feature is enabled.
  Default: false (opt-in rollout).
  """
  def wingman_enabled? do
    enabled?(:wingman)
  end

  @doc """
  Returns the cache TTL for wingman suggestions in seconds.
  Default: 86400 (24 hours)
  """
  def wingman_cache_ttl do
    get_system_setting_value(:wingman_cache_ttl, 86_400)
  end

  # --- Spellcheck Settings ---

  @doc """
  Returns whether the spellcheck feature is enabled.
  """
  def spellcheck_enabled? do
    enabled?(:spellcheck)
  end

  @doc """
  Returns whether wingman is available (enabled AND queue not overloaded).
  """
  def wingman_available? do
    wingman_enabled?() and not ai_queue_overloaded?()
  end

  @doc """
  Returns whether spellcheck is available (enabled AND queue not overloaded).
  """
  def spellcheck_available? do
    spellcheck_enabled?() and not ai_queue_overloaded?()
  end

  defp ai_queue_overloaded? do
    false
  end
end
