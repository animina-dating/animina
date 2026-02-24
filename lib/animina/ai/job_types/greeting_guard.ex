defmodule Animina.AI.JobTypes.GreetingGuard do
  @moduledoc """
  AI job type for classifying whether a message is a generic greeting.

  P10 priority, uses qwen3:8b text model.
  Returns %{"is_generic_greeting" => bool} via PubSub.
  """

  @behaviour Animina.AI.JobType

  alias Animina.AI.JobType

  require Logger

  @impl true
  def job_type, do: "greeting_guard"

  @impl true
  def model_family, do: :text

  @impl true
  def model, do: "qwen3:8b"

  @impl true
  def priority, do: 10

  @impl true
  def max_attempts, do: 1

  @impl true
  def build_prompt(%{"content" => content}), do: content
  @impl true
  def build_prompt(_), do: raise("GreetingGuard job requires a 'content' param")

  @impl true
  def prepare_input(%{"sender_name" => sender_name, "recipient_name" => recipient_name}) do
    system =
      "You are a dating message classifier. " <>
        "#{sender_name} is sending a first message to #{recipient_name}. " <>
        "Classify whether the message is a generic greeting (like \"Hi\", \"Hello\", " <>
        "\"Hey\", \"Hallo #{recipient_name}!\", \"Na?\", \"Wie geht's?\", \"What's up?\") " <>
        "that shows no personal effort, or whether it contains something personal or specific. " <>
        "Respond with JSON: {\"is_generic_greeting\": true} or {\"is_generic_greeting\": false}"

    {:ok, [api_opts: [think: false, system: system, format: "json"]]}
  end

  @impl true
  def prepare_input(_), do: {:ok, [api_opts: [think: false, system: "", format: "json"]]}

  @impl true
  def handle_result(job, raw_response) do
    case parse_response(raw_response) do
      {:ok, value} ->
        {:ok, %{"is_generic_greeting" => value}}

      {:error, :unparseable} ->
        Logger.warning("GreetingGuard: failed to parse response for job #{job.id}")
        {:error, :unparseable}
    end
  end

  @doc """
  Fast Elixir pre-filter. Returns true when the message should be checked by AI.
  """
  @max_short_length 25

  def should_check?(sender, recipient, content, messages) do
    trimmed = String.trim(content || "")

    sender.gender == "male" &&
      recipient.gender == "female" &&
      Enum.empty?(messages) &&
      trimmed != "" &&
      not String.contains?(trimmed, "\n") &&
      String.length(trimmed) < @max_short_length &&
      sender.wingman_enabled == true &&
      Animina.FeatureFlags.wingman_available?()
  end

  # --- Parsing ---

  defp parse_response(nil), do: {:error, :unparseable}

  defp parse_response(response) when is_binary(response) do
    cleaned =
      response
      |> JobType.strip_think_tags()
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

end
