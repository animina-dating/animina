defmodule Animina.AI.JobType do
  @moduledoc """
  Behaviour for AI job type implementations.

  Each job type (photo classification, gender guess, photo description)
  implements this behaviour to define its model, prompt, and result handling.
  """

  @type params :: map()
  @type job :: Animina.AI.Job.t()

  @doc "Returns the string identifier for this job type."
  @callback job_type() :: String.t()

  @doc "Returns the model family: :vision or :text."
  @callback model_family() :: :vision | :text

  @doc "Returns the default model to use."
  @callback default_model() :: String.t()

  @doc "Returns the default priority (1=critical, 5=background)."
  @callback default_priority() :: integer()

  @doc "Returns the maximum number of retry attempts."
  @callback max_attempts() :: integer()

  @doc "Returns a list of models to try if the default fails or is too slow."
  @callback allowed_model_downgrades() :: [String.t()]

  @doc "Builds the prompt string from job params."
  @callback build_prompt(params()) :: String.t()

  @doc "Prepares input data (e.g., load and encode images). Returns {:ok, keyword()} with opts for Client."
  @callback prepare_input(params()) :: {:ok, keyword()} | {:error, term()}

  @doc "Handles a successful result — parse response, trigger side effects. Returns {:ok, result_map} or {:error, reason}."
  @callback handle_result(job(), String.t()) :: {:ok, map()} | {:error, term()}
end
