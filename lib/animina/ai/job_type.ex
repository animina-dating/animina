defmodule Animina.AI.JobType do
  @moduledoc """
  Behaviour for AI job type implementations.

  Each job type defines a fixed model, priority, and how to build prompts
  and handle results. No model downgrades — one model per job type.
  """

  @type params :: map()
  @type job :: Animina.AI.Job.t()

  @doc "Returns the string identifier for this job type."
  @callback job_type() :: String.t()

  @doc "Returns the model family: :vision or :text."
  @callback model_family() :: :vision | :text

  @doc "Returns the fixed model to use."
  @callback model() :: String.t()

  @doc "Returns the default priority (10-50 scale)."
  @callback priority() :: integer()

  @doc "Returns the maximum number of retry attempts."
  @callback max_attempts() :: integer()

  @doc "Builds the prompt string from job params."
  @callback build_prompt(params()) :: String.t()

  @doc "Prepares input data (e.g., load and encode images). Returns {:ok, keyword()} with opts for Client."
  @callback prepare_input(params()) :: {:ok, keyword()} | {:error, term()}

  @doc "Handles a successful result — parse response, trigger side effects. Returns {:ok, result_map} or {:error, reason}."
  @callback handle_result(job(), String.t()) :: {:ok, map()} | {:error, term()}

  @doc "Strips `<think>...</think>` tags that some models emit before the actual response."
  @spec strip_think_tags(String.t()) :: String.t()
  def strip_think_tags(text) do
    text
    |> String.replace(~r/<think>[\s\S]*?<\/think>/i, "")
    |> String.replace(~r/<think>[\s\S]*/i, "")
    |> String.replace(~r"\s*/think\s*", "")
  end
end
