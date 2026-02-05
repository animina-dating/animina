defmodule Animina.FeatureFlagsTest do
  use Animina.DataCase, async: true

  alias Animina.FeatureFlags
  alias Animina.FeatureFlags.FlagSetting

  describe "flag settings" do
    test "create_flag_setting/1 creates a setting with valid attrs" do
      attrs = %{
        flag_name: "photo_nsfw_check",
        description: "Run NSFW detection on photos",
        settings: %{auto_approve: false, delay_ms: 0}
      }

      assert {:ok, %FlagSetting{} = setting} = FeatureFlags.create_flag_setting(attrs)
      assert setting.flag_name == "photo_nsfw_check"
      assert setting.description == "Run NSFW detection on photos"
      # Settings map keys may be atoms or strings depending on context
      assert setting.settings[:auto_approve] == false || setting.settings["auto_approve"] == false
      assert setting.settings[:delay_ms] == 0 || setting.settings["delay_ms"] == 0
    end

    test "create_flag_setting/1 fails with duplicate flag_name" do
      attrs = %{flag_name: "photo_nsfw_check", settings: %{}}
      assert {:ok, _} = FeatureFlags.create_flag_setting(attrs)
      assert {:error, changeset} = FeatureFlags.create_flag_setting(attrs)
      assert "has already been taken" in errors_on(changeset).flag_name
    end

    test "get_flag_setting/1 returns the setting for a flag" do
      attrs = %{flag_name: "photo_face_detection", settings: %{delay_ms: 500}}
      {:ok, created} = FeatureFlags.create_flag_setting(attrs)

      assert setting = FeatureFlags.get_flag_setting("photo_face_detection")
      assert setting.id == created.id
      assert setting.settings["delay_ms"] == 500
    end

    test "get_flag_setting/1 returns nil for non-existent flag" do
      assert nil == FeatureFlags.get_flag_setting("nonexistent_flag")
    end

    test "update_flag_setting/2 updates the setting" do
      {:ok, setting} =
        FeatureFlags.create_flag_setting(%{
          flag_name: "test_flag",
          settings: %{auto_approve: false}
        })

      assert {:ok, updated} =
               FeatureFlags.update_flag_setting(setting, %{
                 settings: %{auto_approve: true, delay_ms: 1000}
               })

      # Settings map keys may be atoms or strings depending on context
      assert updated.settings[:auto_approve] == true || updated.settings["auto_approve"] == true
      assert updated.settings[:delay_ms] == 1000 || updated.settings["delay_ms"] == 1000
    end

    test "list_flag_settings/0 returns all settings" do
      initial_count = length(FeatureFlags.list_flag_settings())

      {:ok, _} = FeatureFlags.create_flag_setting(%{flag_name: "custom_flag1", settings: %{}})
      {:ok, _} = FeatureFlags.create_flag_setting(%{flag_name: "custom_flag2", settings: %{}})

      settings = FeatureFlags.list_flag_settings()
      assert length(settings) == initial_count + 2
    end
  end

  describe "flag status checks" do
    test "check_status/2 returns :run when flag is enabled and no auto_approve" do
      FunWithFlags.enable(:photo_nsfw_check)
      {:ok, _} = FeatureFlags.create_flag_setting(%{flag_name: "photo_nsfw_check", settings: %{}})

      assert :run == FeatureFlags.check_status(:photo_nsfw_check, false)
    end

    test "check_status/2 returns {:skip, value} when flag is disabled with auto_approve" do
      FunWithFlags.disable(:photo_nsfw_check)

      {:ok, _} =
        FeatureFlags.create_flag_setting(%{
          flag_name: "photo_nsfw_check",
          settings: %{auto_approve: true, auto_approve_value: false}
        })

      assert {:skip, false} == FeatureFlags.check_status(:photo_nsfw_check, false)
    end

    test "check_status/2 returns :skip when flag is disabled without auto_approve" do
      FunWithFlags.disable(:photo_nsfw_check)
      {:ok, _} = FeatureFlags.create_flag_setting(%{flag_name: "photo_nsfw_check", settings: %{}})

      assert :skip == FeatureFlags.check_status(:photo_nsfw_check, false)
    end

    test "check_status/2 uses default value when no setting exists" do
      FunWithFlags.disable(:unknown_flag)
      assert :skip == FeatureFlags.check_status(:unknown_flag, "default")
    end

    test "enabled?/1 returns true when flag is enabled" do
      FunWithFlags.enable(:test_flag)
      assert FeatureFlags.enabled?(:test_flag) == true
    end

    test "enabled?/1 returns false when flag is disabled" do
      FunWithFlags.disable(:test_flag)
      assert FeatureFlags.enabled?(:test_flag) == false
    end
  end

  describe "apply_delay/1" do
    test "applies configured delay" do
      {:ok, _} =
        FeatureFlags.create_flag_setting(%{
          flag_name: "slow_check",
          settings: %{delay_ms: 50}
        })

      start_time = System.monotonic_time(:millisecond)
      FeatureFlags.apply_delay(:slow_check)
      elapsed = System.monotonic_time(:millisecond) - start_time

      assert elapsed >= 45
    end

    test "no delay when delay_ms is 0" do
      {:ok, _} =
        FeatureFlags.create_flag_setting(%{
          flag_name: "fast_check",
          settings: %{delay_ms: 0}
        })

      start_time = System.monotonic_time(:millisecond)
      FeatureFlags.apply_delay(:fast_check)
      elapsed = System.monotonic_time(:millisecond) - start_time

      # Allow some overhead for slower CI environments
      assert elapsed < 50
    end

    test "no delay when no setting exists" do
      start_time = System.monotonic_time(:millisecond)
      FeatureFlags.apply_delay(:nonexistent_flag)
      elapsed = System.monotonic_time(:millisecond) - start_time

      # Allow some overhead for slower CI environments
      assert elapsed < 50
    end
  end

  describe "photo processing convenience functions" do
    test "ollama_check_enabled?/0 returns flag state" do
      FunWithFlags.enable(:photo_ollama_check)
      assert FeatureFlags.ollama_check_enabled?() == true

      FunWithFlags.disable(:photo_ollama_check)
      assert FeatureFlags.ollama_check_enabled?() == false
    end

    test "blacklist_check_enabled?/0 returns flag state" do
      FunWithFlags.enable(:photo_blacklist_check)
      assert FeatureFlags.blacklist_check_enabled?() == true

      FunWithFlags.disable(:photo_blacklist_check)
      assert FeatureFlags.blacklist_check_enabled?() == false
    end
  end

  describe "enable/1 and disable/1" do
    test "enable/1 enables a flag" do
      FunWithFlags.disable(:test_flag)
      assert {:ok, true} = FeatureFlags.enable(:test_flag)
      assert FeatureFlags.enabled?(:test_flag) == true
    end

    test "disable/1 disables a flag" do
      FunWithFlags.enable(:test_flag)
      assert {:ok, false} = FeatureFlags.disable(:test_flag)
      assert FeatureFlags.enabled?(:test_flag) == false
    end
  end

  describe "get_all_photo_flags/0" do
    test "returns all photo processing flags with their states and settings" do
      # Set specific states for testing
      FunWithFlags.enable(:photo_ollama_check)
      FunWithFlags.enable(:photo_blacklist_check)

      # Update the existing setting with custom values
      setting = FeatureFlags.get_flag_setting(:photo_ollama_check)

      if setting do
        FeatureFlags.update_flag_setting(setting, %{
          settings: %{delay_ms: 100, auto_approve: true, auto_approve_value: true}
        })
      else
        FeatureFlags.create_flag_setting(%{
          flag_name: "photo_ollama_check",
          description: "Ollama Photo Check",
          settings: %{delay_ms: 100, auto_approve: true, auto_approve_value: true}
        })
      end

      flags = FeatureFlags.get_all_photo_flags()

      ollama_check = Enum.find(flags, fn f -> f.name == :photo_ollama_check end)
      assert ollama_check.enabled == true
      assert ollama_check.setting.settings["delay_ms"] == 100

      blacklist = Enum.find(flags, fn f -> f.name == :photo_blacklist_check end)
      assert blacklist.enabled == true
    end
  end

  describe "system settings" do
    test "system_setting_definitions/0 returns all setting definitions" do
      definitions = FeatureFlags.system_setting_definitions()

      assert length(definitions) == 4

      referral_def = Enum.find(definitions, &(&1.name == :referral_threshold))
      assert referral_def.label == "Referral Threshold"
      assert referral_def.default_value == 3
      assert referral_def.min_value == 1
      assert referral_def.max_value == 100

      grace_def = Enum.find(definitions, &(&1.name == :soft_delete_grace_days))
      assert grace_def.label == "Soft Delete Grace Period"
      assert grace_def.default_value == 28
      assert grace_def.min_value == 1
      assert grace_def.max_value == 365

      ollama_def = Enum.find(definitions, &(&1.name == :ollama_model))
      assert ollama_def.label == "Ollama Model"
      assert ollama_def.default_value == "qwen3-vl:8b"
      assert ollama_def.type == :string
    end

    test "referral_threshold/0 returns default value when not configured" do
      assert FeatureFlags.referral_threshold() == 3
    end

    test "soft_delete_grace_days/0 returns default value when not configured" do
      assert FeatureFlags.soft_delete_grace_days() == 28
    end

    test "ollama_model/0 returns default value when not configured" do
      assert FeatureFlags.ollama_model() == "qwen3-vl:8b"
    end

    test "get_system_setting_value/2 returns configured value" do
      {:ok, setting} =
        FeatureFlags.get_or_create_flag_setting("system:referral_threshold", %{
          settings: %{value: 5}
        })

      FeatureFlags.update_flag_setting(setting, %{settings: %{value: 5}})

      assert FeatureFlags.get_system_setting_value(:referral_threshold, 3) == 5
    end

    test "get_system_setting_value/2 returns default when not configured" do
      assert FeatureFlags.get_system_setting_value(:referral_threshold, 3) == 3
    end

    test "get_all_system_settings/0 returns all settings with current values" do
      settings = FeatureFlags.get_all_system_settings()

      assert length(settings) == 4

      referral = Enum.find(settings, &(&1.name == :referral_threshold))
      assert referral.current_value == 3

      grace = Enum.find(settings, &(&1.name == :soft_delete_grace_days))
      assert grace.current_value == 28

      ollama = Enum.find(settings, &(&1.name == :ollama_model))
      assert ollama.current_value == "qwen3-vl:8b"
    end
  end
end
