defmodule Animina.HotDeployTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Animina.HotDeploy

  describe "startup_reapply_current/0" do
    test "returns :ok when disabled" do
      Application.put_env(:animina, HotDeploy, enabled: false)
      assert HotDeploy.startup_reapply_current() == :ok
    after
      Application.delete_env(:animina, HotDeploy)
    end

    test "returns :ok when upgrades_dir does not exist" do
      Application.put_env(:animina, HotDeploy,
        enabled: true,
        upgrades_dir: "/tmp/animina_test_nonexistent_#{System.unique_integer([:positive])}"
      )

      assert HotDeploy.startup_reapply_current() == :ok
    after
      Application.delete_env(:animina, HotDeploy)
    end

    test "does not crash when beam files exist in upgrades dir" do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "animina_test_hot_deploy_#{System.unique_integer([:positive])}"
        )

      lib_dir = Path.join(tmp_dir, "lib/some_app-0.1.0/ebin")
      File.mkdir_p!(lib_dir)

      # Write an invalid beam file to trigger error handling
      File.write!(Path.join(lib_dir, "Elixir.FakeTestModule.beam"), "not a real beam")

      Application.put_env(:animina, HotDeploy,
        enabled: true,
        upgrades_dir: tmp_dir
      )

      # Must not crash the caller — this is the critical invariant
      assert capture_log(fn ->
               assert HotDeploy.startup_reapply_current() == :ok
             end) =~ "Failed to load"
    after
      Application.delete_env(:animina, HotDeploy)
    end

    test "updates version in persistent_term when animina-X.Y.Z dir exists" do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "animina_test_hot_deploy_version_#{System.unique_integer([:positive])}"
        )

      lib_dir = Path.join(tmp_dir, "lib")
      animina_dir = Path.join(lib_dir, "animina-1.2.3/ebin")
      File.mkdir_p!(animina_dir)

      # Write a minimal valid beam file (module compiled in-memory)
      {:module, TestHotDeployVersionModule, binary, _} =
        Module.create(TestHotDeployVersionModule, quote(do: def(hello, do: :world)), __ENV__)

      File.write!(Path.join(animina_dir, "Elixir.TestHotDeployVersionModule.beam"), binary)

      Application.put_env(:animina, HotDeploy,
        enabled: true,
        upgrades_dir: tmp_dir
      )

      # Initialize with compile-time values first
      Animina.initialize_deploy_info()

      assert HotDeploy.startup_reapply_current() == :ok

      assert Animina.version() == "1.2.3"
      assert %DateTime{} = Animina.deployed_at()
    after
      Application.delete_env(:animina, HotDeploy)
      Animina.initialize_deploy_info()
      :code.purge(TestHotDeployVersionModule)
      :code.delete(TestHotDeployVersionModule)
    end

    test "does not update version when no animina-X.Y.Z dir exists" do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "animina_test_hot_deploy_noversion_#{System.unique_integer([:positive])}"
        )

      lib_dir = Path.join(tmp_dir, "lib/some_other_app-0.1.0/ebin")
      File.mkdir_p!(lib_dir)

      # Write an invalid beam file
      File.write!(Path.join(lib_dir, "Elixir.FakeModule2.beam"), "not a real beam")

      Application.put_env(:animina, HotDeploy,
        enabled: true,
        upgrades_dir: tmp_dir
      )

      Animina.initialize_deploy_info()
      original_version = Animina.version()

      assert HotDeploy.startup_reapply_current() == :ok

      # Version should remain unchanged
      assert Animina.version() == original_version
    after
      Application.delete_env(:animina, HotDeploy)
      Animina.initialize_deploy_info()
    end
  end

  describe "start_link/1" do
    test "returns :ignore when disabled" do
      Application.put_env(:animina, HotDeploy, enabled: false)
      assert HotDeploy.start_link() == :ignore
    after
      Application.delete_env(:animina, HotDeploy)
    end
  end
end
