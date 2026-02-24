defmodule Animina.Wingman.PreheaterTest do
  use Animina.DataCase, async: false

  alias Animina.Wingman.Preheater

  import Animina.AccountsFixtures

  defp make_normal(user) do
    user
    |> Ecto.Changeset.change(state: "normal")
    |> Animina.Repo.update!()
  end

  describe "run/0" do
    test "skips when wingman feature flag is disabled" do
      FunWithFlags.disable(:wingman)

      assert :disabled = Preheater.run()
    end

    test "runs successfully with wingman enabled" do
      FunWithFlags.enable(:wingman)

      user_fixture(language: "en", display_name: "Preheater Test") |> make_normal()

      result = Preheater.run()
      assert is_map(result)
      assert Map.has_key?(result, :enqueued)
      assert Map.has_key?(result, :skipped)
      assert Map.has_key?(result, :users)
      assert Map.has_key?(result, :cancelled)

      FunWithFlags.disable(:wingman)
    end

    test "processes wingman users and enqueues jobs" do
      FunWithFlags.enable(:wingman)

      user_fixture(language: "en", display_name: "User One") |> make_normal()
      user_fixture(language: "en", display_name: "User Two") |> make_normal()

      result = Preheater.run()

      # Should have found at least 2 users
      assert result.users >= 2

      FunWithFlags.disable(:wingman)
    end
  end
end
