defmodule Animina.AI.JobTypes.PreheatedWingman do
  @moduledoc """
  AI job type for pre-computed wingman conversation hints.

  P50 priority (lowest), uses qwen3:8b text model.
  Results are stored in `preheated_wingman_hints` table.
  """

  @behaviour Animina.AI.JobType

  require Logger

  alias Animina.Wingman

  @impl true
  def job_type, do: "preheated_wingman"

  @impl true
  def model_family, do: :text

  @impl true
  def model, do: "qwen3:8b"

  @impl true
  def priority, do: 50

  @impl true
  def max_attempts, do: 1

  @impl true
  def build_prompt(%{"prompt" => prompt}), do: prompt
  @impl true
  def build_prompt(_), do: raise("PreheatedWingman job requires a 'prompt' param")

  @impl true
  def prepare_input(_params) do
    {:ok, [api_opts: [think: false]]}
  end

  @impl true
  def handle_result(job, raw_response) do
    user_id = job.params["user_id"]
    other_user_id = job.params["other_user_id"]
    shown_on = Date.from_iso8601!(job.params["shown_on"])
    context_hash = job.params["context_hash"]

    case Wingman.parse_suggestions(raw_response) do
      {:ok, suggestions} ->
        Wingman.save_preheated_hint(user_id, other_user_id, shown_on, suggestions, context_hash, job.id)
        {:ok, %{"suggestions" => suggestions}}

      {:error, :parse_failed} ->
        Logger.warning("PreheatedWingman: failed to parse response: #{inspect(raw_response)}")
        {:error, :parse_failed}
    end
  end
end
