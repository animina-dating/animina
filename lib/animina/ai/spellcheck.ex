defmodule Animina.AI.SpellCheck do
  @moduledoc """
  LLM-powered spelling and grammar correction for chat messages.

  Uses the Ollama API via `AI.Client` for direct, low-latency calls.
  The prompt is language-agnostic — the LLM detects the language automatically.

  Requests JSON output (`format: "json"`) so the corrected text can be
  reliably extracted even when the model leaks reasoning/thinking.
  """

  require Logger

  alias Animina.AI.Client
  alias Animina.FeatureFlags

  @doc """
  Checks and corrects spelling/grammar in the given text.

  Accepts an optional keyword list with `:age` and `:gender` to give the LLM
  context about the writer (different age groups have different writing norms).

  Returns `{:ok, corrected_text}` or `{:error, reason}`.
  """
  @spec check_text(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def check_text(text, opts \\ []) do
    model = FeatureFlags.spellcheck_model()
    system = build_system_prompt(opts)

    case Client.completion(
           model: model,
           prompt: text,
           instance_filter: &gpu_instance?/1,
           api_opts: [think: false, system: system, format: "json"]
         ) do
      {:ok, %{"response" => response}, _server_url} ->
        {:ok, parse_response(response, text)}

      {:ok, _unexpected, _server_url} ->
        {:error, :unexpected_response}

      {:error, reason} ->
        Logger.warning("SpellCheck failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Builds the system prompt for the spell/grammar check.

  The system prompt contains instructions and optional writer context.
  The user's text is sent separately as the `prompt` parameter.
  """
  @spec build_system_prompt(keyword()) :: String.t()
  def build_system_prompt(opts \\ []) do
    context = build_context(opts)

    "Proofread and fix the user's text. Correct all spelling, grammar, and punctuation errors. " <>
      "Keep the same language — do not translate. Keep the same tone and style. " <>
      ~s[Respond with JSON: {"text": "corrected text here"}] <>
      context
  end

  defp gpu_instance?(instance), do: "gpu" in Map.get(instance, :tags, [])

  defp build_context(opts) do
    age = Keyword.get(opts, :age)
    gender = Keyword.get(opts, :gender)

    case {age, gender} do
      {nil, nil} -> ""
      {age, nil} -> " The writer is #{age} years old."
      {nil, gender} -> " The writer is #{gender}."
      {age, gender} -> " The writer is a #{age}-year-old #{gender}."
    end
  end

  @doc """
  Parses the LLM response, extracting the corrected text.

  Tries JSON extraction first (primary), then falls back to heuristic
  stripping of thinking/reasoning artifacts.

  Returns the original text if the response is empty or nil.
  """
  @spec parse_response(String.t() | nil, String.t()) :: String.t()
  def parse_response(nil, original), do: original

  def parse_response(response, original) do
    cleaned =
      response
      |> strip_think_tags()
      |> String.trim()

    cond do
      cleaned == "" ->
        original

      json_text = extract_json_text(cleaned) ->
        json_text

      true ->
        cleaned
        |> strip_untagged_thinking(original)
        |> strip_surrounding_quotes()
        |> fallback_to_original(original)
    end
  end

  # Try to extract the "text" field from a JSON response.
  # Handles both clean JSON and JSON embedded after thinking output.
  defp extract_json_text(text) do
    with {:ok, %{"text" => value}} when is_binary(value) <- Jason.decode(text),
         trimmed = String.trim(value),
         true <- trimmed != "" do
      trimmed
    else
      _ -> extract_json_from_end(text)
    end
  end

  # When the model prepends thinking before the JSON, find the last JSON object.
  defp extract_json_from_end(text) do
    case Regex.run(~r/\{[^{}]*"text"\s*:\s*"([^"]*)"[^{}]*\}\s*$/s, text) do
      [_, value] when value != "" -> String.trim(value)
      _ -> nil
    end
  end

  # When the model outputs reasoning without <think> tags, the response is
  # much longer than the input. Scan backwards through lines to find the
  # corrected text, which models place at the end of their reasoning.
  defp strip_untagged_thinking(text, original) do
    if String.length(text) > String.length(original) * 3 do
      max_len = max(String.length(original) * 2, 100)

      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reverse()
      |> Enum.find(fn line ->
        len = String.length(line)
        len > 3 and len <= max_len and not reasoning_line?(line)
      end)
      |> case do
        nil -> original
        answer -> answer
      end
    else
      text
    end
  end

  defp fallback_to_original("", original), do: original
  defp fallback_to_original(result, _original), do: result

  @reasoning_prefix ~r/^(\d+[\.\)]\s|[-*]\s|So\s|Wait|Hmm|But\s|However|Let me|Check|Also|Therefore|Note:|Important|The user|The error|The correct|Make sure|In\s(German|English|standard)|We are|Okay|First|Steps|Looking|I need|Yes|No[\s,])/i
  defp reasoning_line?(line), do: Regex.match?(@reasoning_prefix, line)

  # qwen3 models sometimes emit <think>...</think> reasoning blocks.
  # Handle both closed and unclosed <think> tags.
  defp strip_think_tags(text) do
    text
    |> String.replace(~r/<think>[\s\S]*?<\/think>/i, "")
    |> String.replace(~r/<think>[\s\S]*/i, "")
    |> String.replace(~r"\s*/think\s*", "")
  end

  @surrounding_quotes ~r/\A(["'`])([\s\S]+)\1\z/
  defp strip_surrounding_quotes(text) do
    case Regex.run(@surrounding_quotes, text) do
      [_, _quote, inner] -> String.trim(inner)
      _ -> text
    end
  end
end
