defmodule Animina.Accounts.GenderGuesser do
  @moduledoc """
  Guesses the gender associated with a first name using a cache table
  and Ollama as fallback.
  """

  alias Animina.Accounts.FirstNameGender
  alias Animina.Photos
  alias Animina.Repo

  import Ecto.Query

  require Logger

  @model "qwen3:1.7b"
  @timeout 15_000

  @doc """
  Synchronously guesses gender for a first name.

  Returns `{:ok, "male" | "female"}` on success, or `:unknown` if
  the name is blank or Ollama is unreachable and no cache entry exists.
  """
  def guess(first_name) do
    name = normalize(first_name)

    if name == "" do
      :unknown
    else
      case lookup_cache(name) do
        {:ok, gender} -> {:ok, gender}
        :miss -> guess_via_ollama(name)
      end
    end
  end

  defp guess_via_ollama(name) do
    case ask_ollama(name) do
      {:ok, gender, needs_review} ->
        insert_cache(name, gender, needs_review)
        {:ok, gender}

      :error ->
        :unknown
    end
  end

  @doc """
  Cache-only lookup (no Ollama call). Returns `{:ok, gender}` or `:miss`.
  Used as a fast safety net when the async guess hasn't completed yet.
  """
  def guess_from_cache(first_name) do
    name = normalize(first_name)
    if name == "", do: :miss, else: lookup_cache(name)
  end

  @doc """
  Asynchronously guesses gender and sends `{:gender_guess_result, result}`
  to the caller pid. Result is `"male"`, `"female"`, or `nil`.
  """
  def guess_async(first_name, caller_pid \\ self()) do
    Task.start(fn ->
      result =
        case guess(first_name) do
          {:ok, gender} -> gender
          :unknown -> nil
        end

      send(caller_pid, {:gender_guess_result, result})
    end)
  end

  defp normalize(nil), do: ""
  defp normalize(name), do: name |> String.trim() |> String.downcase()

  defp lookup_cache(name) do
    query = from(f in FirstNameGender, where: f.first_name == ^name, select: f.gender)

    case Repo.one(query) do
      nil -> :miss
      gender -> {:ok, gender}
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

  defp ask_ollama(name) do
    url = ollama_url()
    client = Ollama.init(base_url: url, receive_timeout: @timeout)

    prompt =
      "For a dating platform: Is the first name '#{name}' more commonly male or female? " <>
        "Respond with ONLY valid JSON: {\"gender\": \"male\"} or {\"gender\": \"female\"}."

    case Ollama.completion(client, model: @model, prompt: prompt) do
      {:ok, %{"response" => response}} ->
        parse_response(response)

      {:error, reason} ->
        Logger.warning("GenderGuesser: Ollama error for '#{name}': #{inspect(reason)}")
        :error
    end
  rescue
    e ->
      Logger.warning("GenderGuesser: Ollama exception for '#{name}': #{inspect(e)}")
      :error
  end

  defp parse_response(response) do
    # Extract JSON from response (model may include thinking tags or extra text)
    case Regex.run(~r/\{(?:[^{}]|\{[^{}]*\})*\}/s, response) do
      [json_str] ->
        case Jason.decode(json_str) do
          {:ok, %{"gender" => gender}} when gender in ["male", "female"] ->
            {:ok, gender, false}

          _ ->
            Logger.warning("GenderGuesser: unexpected JSON: #{inspect(json_str)}")
            {:ok, "male", true}
        end

      nil ->
        Logger.warning("GenderGuesser: no JSON found in response: #{inspect(response)}")
        {:ok, "male", true}
    end
  end

  defp ollama_url do
    case Photos.ollama_instances() do
      [%{url: url} | _] -> url
      _ -> "http://localhost:11434/api"
    end
  end
end
