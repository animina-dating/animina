defmodule Animina.AI.JobTypes.GenderGuess do
  @moduledoc """
  AI job type for guessing gender from a first name.

  P10 priority, uses qwen3:1.7b text model.
  Results are cached in the first_name_genders table.
  """

  @behaviour Animina.AI.JobType

  require Logger

  alias Animina.Accounts.FirstNameGender
  alias Animina.Repo

  @impl true
  def job_type, do: "gender_guess"

  @impl true
  def model_family, do: :text

  @impl true
  def model, do: "qwen3:1.7b"

  @impl true
  def priority, do: 10

  @impl true
  def max_attempts, do: 1

  @impl true
  def build_prompt(%{"name" => name}) do
    "For a dating platform: Is the first name '#{name}' more commonly male or female? " <>
      "Respond with ONLY valid JSON: {\"gender\": \"male\"} or {\"gender\": \"female\"}."
  end

  @impl true
  def build_prompt(_), do: raise("GenderGuess job requires a 'name' param")

  @impl true
  def prepare_input(_params) do
    {:ok, []}
  end

  @impl true
  def handle_result(job, raw_response) do
    name = job.params["name"]

    case parse_response(raw_response) do
      {:ok, gender, needs_review} ->
        insert_cache(name, gender, needs_review)
        {:ok, %{"gender" => gender, "needs_review" => needs_review}}

      :error ->
        insert_cache(name, "male", true)
        {:ok, %{"gender" => "male", "needs_review" => true, "parse_error" => true}}
    end
  end

  # --- Private ---

  defp parse_response(response) do
    case Regex.run(~r/\{(?:[^{}]|\{[^{}]*\})*\}/s, response) do
      [json_str] ->
        case Jason.decode(json_str) do
          {:ok, %{"gender" => gender}} when gender in ["male", "female"] ->
            {:ok, gender, false}

          _ ->
            Logger.warning("GenderGuess: unexpected JSON: #{inspect(json_str)}")
            {:ok, "male", true}
        end

      nil ->
        Logger.warning("GenderGuess: no JSON found in response: #{inspect(response)}")
        :error
    end
  end

  defp insert_cache(name, gender, needs_review) do
    %FirstNameGender{}
    |> FirstNameGender.changeset(%{
      first_name: name,
      gender: gender,
      needs_human_review: needs_review
    })
    |> Repo.insert(on_conflict: :nothing)
  end
end
