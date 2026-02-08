defmodule Animina.Accounts.GenderGuesserTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.FirstNameGender
  alias Animina.Accounts.GenderGuesser
  alias Animina.Repo

  describe "guess/1" do
    test "returns cached gender on cache hit" do
      Repo.insert!(%FirstNameGender{
        first_name: "stefan",
        gender: "male",
        needs_human_review: false
      })

      assert {:ok, "male"} = GenderGuesser.guess("Stefan")
    end

    test "is case-insensitive" do
      Repo.insert!(%FirstNameGender{
        first_name: "maria",
        gender: "female",
        needs_human_review: false
      })

      assert {:ok, "female"} = GenderGuesser.guess("MARIA")
      assert {:ok, "female"} = GenderGuesser.guess("maria")
      assert {:ok, "female"} = GenderGuesser.guess("Maria")
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
      Repo.insert!(%FirstNameGender{
        first_name: "hans",
        gender: "male",
        needs_human_review: false
      })

      assert {:ok, "male"} = GenderGuesser.guess_from_cache("Hans")
    end

    test "returns :miss for uncached name" do
      assert :miss = GenderGuesser.guess_from_cache("Zyxwvutest")
    end
  end

  describe "guess_async/2" do
    test "sends {:gender_guess_result, value} to caller" do
      Repo.insert!(%FirstNameGender{
        first_name: "anna",
        gender: "female",
        needs_human_review: false
      })

      GenderGuesser.guess_async("Anna", self())

      assert_receive {:gender_guess_result, "female"}, 1_000
    end

    test "sends {:gender_guess_result, result} to caller for uncached name" do
      GenderGuesser.guess_async("Xyztestname", self())

      # Result depends on whether Ollama is running — either a gender or nil
      assert_receive {:gender_guess_result, result}, 10_000
      assert result in ["male", "female", nil]
    end
  end
end
