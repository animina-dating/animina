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
      name: :photo_ollama_check,
      label: "Ollama Photo Check",
      description: "Photo classification using Ollama vision model",
      default_auto_approve_value: true
    },
    %{
      name: :photo_blacklist_check,
      label: "Blacklist Check",
      description: "Check photos against dhash blacklist",
      default_auto_approve_value: nil
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
end
