defmodule Animina.AI.JobTypes.WingmanSuggestion do
  @moduledoc """
  AI job type for generating wingman conversation coaching suggestions.

  Dual-mode:
  - **On-demand** (P20): `conversation_id` is present in params — saves and broadcasts.
  - **Preheated** (P50): `conversation_id` is absent — saves as a preheated hint (no broadcast).

  Uses qwen3:14b text model.
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
  def model, do: "qwen3:14b"

  @impl true
  def priority, do: 20

  @impl true
  def max_attempts, do: 1

  @impl true
  def build_prompt(%{"prompt" => prompt}), do: prompt
  def build_prompt(_), do: raise("WingmanSuggestion job requires a 'prompt' param")

  @impl true
  def prepare_input(_params) do
    {:ok, [api_opts: [think: false]]}
  end

  @impl true
  def handle_result(job, raw_response) do
    case Wingman.parse_suggestions(raw_response) do
      {:ok, suggestions} ->
        if job.params["conversation_id"] do
          handle_on_demand(job, suggestions)
        else
          handle_preheated(job, suggestions)
        end

      {:error, :parse_failed} ->
        Logger.warning("WingmanSuggestion: failed to parse response: #{inspect(raw_response)}")
        {:error, :parse_failed}
    end
  end

  defp handle_on_demand(job, suggestions) do
    conversation_id = job.params["conversation_id"]
    user_id = job.params["user_id"]
    context_hash = job.params["context_hash"]

    Wingman.save_and_broadcast(conversation_id, user_id, suggestions, context_hash, job.id)

    ActivityLog.log(
      "system",
      "wingman_generated",
      "Generated wingman suggestions for conversation",
      actor_id: user_id,
      metadata: %{
        "conversation_id" => conversation_id,
        "suggestion_count" => length(suggestions)
      }
    )

    {:ok, %{"suggestions" => suggestions}}
  end

  defp handle_preheated(job, suggestions) do
    user_id = job.params["user_id"]
    other_user_id = job.params["other_user_id"]
    shown_on = Date.from_iso8601!(job.params["shown_on"])
    context_hash = job.params["context_hash"]

    Wingman.save_preheated_hint(
      user_id,
      other_user_id,
      shown_on,
      suggestions,
      context_hash,
      job.id
    )

    {:ok, %{"suggestions" => suggestions}}
  end
end
