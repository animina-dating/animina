defmodule Animina.AI.JobTypes.SpellCheck do
  @moduledoc """
  AI job type for LLM-powered spelling and grammar correction.

  P20 priority, uses qwen3:8b text model.
  Returns %{"corrected_text" => string} via PubSub.
  """

  @behaviour Animina.AI.JobType

  alias Animina.AI.JobType

  @impl true
  def job_type, do: "spellcheck"

  @impl true
  def model_family, do: :text

  @impl true
  def model, do: "qwen3:8b"

  @impl true
  def priority, do: 20

  @impl true
  def max_attempts, do: 1

  @impl true
  def build_prompt(%{"text" => text}), do: text
  @impl true
  def build_prompt(_), do: raise("SpellCheck job requires a 'text' param")

  @impl true
  def prepare_input(params) do
    system = build_system_prompt(params)
    {:ok, [api_opts: [think: false, system: system, format: "json"]]}
  end

  @impl true
  def handle_result(_job, raw_response) do
    corrected = parse_response(raw_response)
    {:ok, %{"corrected_text" => corrected}}
  end

  # --- System prompt ---

  defp build_system_prompt(params) do
    context = build_context(params)

    "Proofread and fix the user's text. Correct all spelling, grammar, and punctuation errors. " <>
      "Keep the same language — do not translate. Keep the same tone and style. " <>
      ~s[Respond with JSON: {"text": "corrected text here"}] <>
      context
  end

  defp build_context(params) do
    age = params["age"]
    gender = params["gender"]

    case {age, gender} do
      {nil, nil} -> ""
      {age, nil} -> " The writer is #{age} years old."
      {nil, gender} -> " The writer is #{gender}."
      {age, gender} -> " The writer is a #{age}-year-old #{gender}."
    end
  end

  # --- Response parsing ---

  @doc """
  Parses the LLM response, extracting the corrected text.
  """
  def parse_response(nil), do: nil

  def parse_response(response) do
    cleaned =
      response
      |> JobType.strip_think_tags()
      |> String.trim()

    cond do
      cleaned == "" ->
        nil

      json_text = extract_json_text(cleaned) ->
        json_text

      true ->
        cleaned
        |> strip_surrounding_quotes()
    end
  end

  defp extract_json_text(text) do
    with {:ok, %{"text" => value}} when is_binary(value) <- Jason.decode(text),
         trimmed = String.trim(value),
         true <- trimmed != "" do
      trimmed
    else
      _ -> extract_json_from_end(text)
    end
  end

  defp extract_json_from_end(text) do
    case Regex.run(~r/\{[^{}]*"text"\s*:\s*"([^"]*)"[^{}]*\}\s*$/s, text) do
      [_, value] when value != "" -> String.trim(value)
      _ -> nil
    end
  end

  @surrounding_quotes ~r/\A(["'`])([\s\S]+)\1\z/
  defp strip_surrounding_quotes(text) do
    case Regex.run(@surrounding_quotes, text) do
      [_, _quote, inner] -> String.trim(inner)
      _ -> text
    end
  end
end
