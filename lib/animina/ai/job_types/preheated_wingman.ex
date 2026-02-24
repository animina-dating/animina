defmodule Animina.AI.JobTypes.PreheatedWingman do
  @moduledoc """
  AI job type for pre-computed wingman conversation hints.

  Identical prompt/model to WingmanSuggestion but runs at priority 5
  (lowest) so it only uses GPU/CPU when idle. Results are stored in the
  `preheated_wingman_hints` table instead of `wingman_suggestions`.
  """

  @behaviour Animina.AI.JobType

  require Logger

  alias Animina.Wingman

  @impl true
  def job_type, do: "preheated_wingman"

  @impl true
  def model_family, do: :text

  @impl true
  def default_model, do: "qwen3:8b"

  @impl true
  def default_priority, do: 5

  @impl true
  def max_attempts, do: 1

  @impl true
  def allowed_model_downgrades, do: []

  @impl true
  def build_prompt(%{"prompt" => prompt}), do: prompt
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
