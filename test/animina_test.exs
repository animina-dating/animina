defmodule AniminaTest do
  use ExUnit.Case, async: true

  describe "version/0" do
    test "returns a semver string" do
      version = Animina.version()
      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+/
    end
  end

  describe "deployed_at/0" do
    test "returns a DateTime" do
      assert %DateTime{} = Animina.deployed_at()
    end
  end

  describe "set_deploy_info/2" do
    test "updates version and deployed_at" do
      Animina.set_deploy_info("99.99.99", ~U[2025-06-15 12:00:00Z])

      assert Animina.version() == "99.99.99"
      assert Animina.deployed_at() == ~U[2025-06-15 12:00:00Z]
    after
      # Restore original values so other tests are not affected
      Animina.initialize_deploy_info()
    end
  end

  describe "initialize_deploy_info/0" do
    test "resets to compile-time values" do
      Animina.set_deploy_info("0.0.0-test", ~U[2000-01-01 00:00:00Z])
      Animina.initialize_deploy_info()

      version = Animina.version()
      assert version =~ ~r/^\d+\.\d+\.\d+/
      assert version != "0.0.0-test"

      deployed_at = Animina.deployed_at()
      assert %DateTime{} = deployed_at
      assert deployed_at != ~U[2000-01-01 00:00:00Z]
    end
  end
end
