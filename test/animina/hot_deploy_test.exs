defmodule Animina.HotDeployTest do
  use ExUnit.Case, async: true

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
