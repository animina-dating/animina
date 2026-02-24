defmodule Animina.Accounts.GenderGuesser do
  @moduledoc """
  Guesses the gender associated with a first name using a cache table
  and Ollama as fallback.
  """

  alias Animina.Accounts.FirstNameGender
  alias Animina.AI
  alias Animina.Repo

  import Ecto.Query

  require Logger

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
    case AI.enqueue_and_wait("gender_guess", %{"name" => name},
           subject_type: "User",
           timeout: 30_000,
           expires_at: DateTime.utc_now() |> DateTime.add(20, :second)
         ) do
      {:ok, %{"gender" => gender}} ->
        {:ok, gender}

      {:error, reason} ->
        Logger.warning("GenderGuesser: AI job failed for '#{name}': #{inspect(reason)}")
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
end
