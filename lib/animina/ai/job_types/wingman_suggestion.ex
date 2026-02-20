defmodule Animina.AI.JobTypes.WingmanSuggestion do
  @moduledoc """
  AI job type for generating wingman conversation coaching suggestions.

  Uses a text model to produce personalized conversation tips based on
  publicly visible profile data from both users.
  """

  @behaviour Animina.AI.JobType

  require Logger

  alias Animina.ActivityLog
  alias Animina.Wingman

  @impl true
  def job_type, do: "wingman_suggestion"

  @impl true
  def model_family, do: :text

  @impl true
  def default_model, do: "qwen3:8b"

  @impl true
  def default_priority, do: 2

  @impl true
  def max_attempts, do: 2

  @impl true
  def allowed_model_downgrades, do: []

  @impl true
  def build_prompt(%{"prompt" => prompt}), do: prompt
  def build_prompt(_), do: raise("WingmanSuggestion job requires a 'prompt' param")

  @impl true
  def prepare_input(_params) do
    # Text-only — no images needed
    {:ok, []}
  end

  @impl true
  def handle_result(job, raw_response) do
    conversation_id = job.params["conversation_id"]
    user_id = job.params["user_id"]
    context_hash = job.params["context_hash"]

    case Wingman.parse_suggestions(raw_response) do
      {:ok, suggestions} ->
        Wingman.save_and_broadcast(conversation_id, user_id, suggestions, context_hash, job.id)

        ActivityLog.log("system", "wingman_generated",
          "Generated wingman suggestions for conversation",
          actor_id: user_id,
          metadata: %{
            "conversation_id" => conversation_id,
            "suggestion_count" => length(suggestions)
          }
        )

        {:ok, %{"suggestions" => suggestions}}

      {:error, :parse_failed} ->
        Logger.warning("WingmanSuggestion: failed to parse response: #{inspect(raw_response)}")
        {:error, :parse_failed}
    end
  end
end
