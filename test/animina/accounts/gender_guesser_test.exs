defmodule Animina.Accounts.GenderGuesserTest do
  # Not async because guess_async spawns tasks that need DB sandbox access
  use Animina.DataCase, async: false

  alias Animina.Accounts.FirstNameGender
  alias Animina.Accounts.GenderGuesser
  alias Animina.Repo

  import Ecto.Query

  # With async: false, the sandbox is in shared mode by default,
  # so spawned tasks can already access the DB connection.

  defp ensure_cached(name, gender) do
    case Repo.one(from f in FirstNameGender, where: f.first_name == ^name) do
      nil ->
        Repo.insert!(%FirstNameGender{
          first_name: name,
          gender: gender,
          needs_human_review: false
        })

      existing ->
        existing
    end
  end

  describe "guess/1" do
    test "returns cached gender on cache hit" do
      ensure_cached("stefan", "male")
      assert {:ok, "male"} = GenderGuesser.guess("Stefan")
    end

    test "is case-insensitive" do
      ensure_cached("maria", "female")

      assert {:ok, _gender} = GenderGuesser.guess("MARIA")
      assert {:ok, _gender} = GenderGuesser.guess("maria")
      assert {:ok, _gender} = GenderGuesser.guess("Maria")
    end

    test "returns :unknown for blank name" do
      assert :unknown = GenderGuesser.guess("")
      assert :unknown = GenderGuesser.guess("  ")
      assert :unknown = GenderGuesser.guess(nil)
    end

    test "returns {:ok, gender} or :unknown when name is not cached (depends on Ollama)" do
      result = GenderGuesser.guess("Xyztestname")

      case result do
        {:ok, gender} -> assert gender in ["male", "female"]
        :unknown -> :ok
      end
    end
  end

  describe "guess_from_cache/1" do
    test "returns {:ok, gender} for cached name" do
      ensure_cached("hans", "male")
      assert {:ok, "male"} = GenderGuesser.guess_from_cache("Hans")
    end

    test "returns :miss for uncached name" do
      assert :miss = GenderGuesser.guess_from_cache("Zyxwvutest")
    end
  end

  describe "guess_async/2" do
    test "sends {:gender_guess_result, value} to caller" do
      ensure_cached("anna", "female")

      GenderGuesser.guess_async("Anna", self())

      assert_receive {:gender_guess_result, "female"}, 1_000
    end

    test "sends {:gender_guess_result, result} to caller for uncached name" do
      GenderGuesser.guess_async("Xyztestname", self())

      # In test env, AI services are disabled so this will return nil (timeout/unknown)
      # In dev with Ollama running, it may return a gender
      assert_receive {:gender_guess_result, result}, 35_000
      assert result in ["male", "female", nil]
    end
  end
end
