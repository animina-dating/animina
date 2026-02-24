defmodule Animina.AI.GreetingGuard do
  @moduledoc """
  Intercepts short, generic greetings from male senders to female recipients.

  Uses a two-step approach:
  1. `should_check?/4` — fast Elixir pre-filter (no AI call)
  2. `check_greeting/3` — calls Ollama to classify the message

  Tied to the Wingman toggle — when Wingman is off, the guard is off too.
  """

  require Logger

  alias Animina.AI.Client
  alias Animina.FeatureFlags

  @max_short_length 25

  @doc """
  Returns true when the message should be checked by the AI greeting guard.

  Pre-filter criteria (all must be true):
  - Sender is male, recipient is female
  - No existing messages in the conversation (first message)
  - Content is a single line under #{@max_short_length} chars (trimmed)
  - Wingman is available globally and enabled on the sender
  """
  @spec should_check?(map(), map(), String.t(), list()) :: boolean()
  def should_check?(sender, recipient, content, messages) do
    trimmed = String.trim(content || "")

    sender.gender == "male" &&
      recipient.gender == "female" &&
      Enum.empty?(messages) &&
      trimmed != "" &&
      not String.contains?(trimmed, "\n") &&
      String.length(trimmed) < @max_short_length &&
      sender.wingman_enabled == true &&
      FeatureFlags.wingman_available?()
  end

  @doc """
  Calls Ollama to classify whether the message is a generic greeting.

  Returns `{:ok, true}` (generic), `{:ok, false}` (not generic), or `{:error, reason}`.
  """
  @spec check_greeting(String.t(), String.t(), String.t()) ::
          {:ok, boolean()} | {:error, term()}
  def check_greeting(content, sender_name, recipient_name) do
    model = FeatureFlags.wingman_model()
    system = build_system_prompt(sender_name, recipient_name)

    case Client.completion(
           model: model,
           prompt: content,
           instance_filter: &gpu_instance?/1,
           api_opts: [think: false, system: system, format: "json"]
         ) do
      {:ok, %{"response" => response}, _server_url} ->
        parse_response(response)

      {:ok, _unexpected, _server_url} ->
        {:error, :unexpected_response}

      {:error, reason} ->
        Logger.warning("GreetingGuard failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def build_system_prompt(sender_name, recipient_name) do
    "You are a dating message classifier. " <>
      "#{sender_name} is sending a first message to #{recipient_name}. " <>
      "Classify whether the message is a generic greeting (like \"Hi\", \"Hello\", " <>
      "\"Hey\", \"Hallo #{recipient_name}!\", \"Na?\", \"Wie geht's?\", \"What's up?\") " <>
      "that shows no personal effort, or whether it contains something personal or specific. " <>
      ~s[Respond with JSON: {"is_generic_greeting": true} or {"is_generic_greeting": false}]
  end

  defp gpu_instance?(instance), do: "gpu" in Map.get(instance, :tags, [])

  @doc """
  Parses the AI response, extracting the is_generic_greeting boolean.
  """
  @spec parse_response(String.t() | nil) :: {:ok, boolean()} | {:error, :unparseable}
  def parse_response(nil), do: {:error, :unparseable}

  def parse_response(response) when is_binary(response) do
    cleaned =
      response
      |> strip_think_tags()
      |> String.trim()

    case extract_json_result(cleaned) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :unparseable}
    end
  end

  defp extract_json_result(text) do
    with {:ok, decoded} <- Jason.decode(text),
         %{"is_generic_greeting" => value} when is_boolean(value) <- decoded do
      {:ok, value}
    else
      _ -> extract_json_from_end(text)
    end
  end

  defp extract_json_from_end(text) do
    case Regex.run(
           ~r/\{[^{}]*"is_generic_greeting"\s*:\s*(true|false)[^{}]*\}\s*$/s,
           text
         ) do
      [_, "true"] -> {:ok, true}
      [_, "false"] -> {:ok, false}
      _ -> :error
    end
  end

  defp strip_think_tags(text) do
    text
    |> String.replace(~r/<think>[\s\S]*?<\/think>/i, "")
    |> String.replace(~r/<think>[\s\S]*/i, "")
    |> String.replace(~r"\s*/think\s*", "")
  end
end
