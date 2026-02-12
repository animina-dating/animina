defmodule Animina.AI.Client do
  @moduledoc """
  Unified Ollama client with cascading failover support.

  Tries configured Ollama instances in priority order, failing over to the
  next instance on connection errors or server issues. Uses circuit breaker
  pattern via HealthTracker to avoid repeatedly trying unhealthy instances.

  Unlike the old Photos.OllamaClient, this module does NOT create log entries.
  Logging is handled at the Executor level via the ai_jobs table.
  """

  require Logger

  alias Animina.AI
  alias Animina.AI.HealthTracker

  @type completion_opts :: [
          model: String.t(),
          prompt: String.t(),
          images: [String.t()],
          target_server: String.t()
        ]

  @failover_eligible_errors [
    :econnrefused,
    :timeout,
    :closed,
    :connect_timeout,
    :ehostunreach,
    :enetunreach,
    :enotconn,
    :connection_closed
  ]

  @failover_eligible_http_codes [429, 500, 502, 503, 504]

  @doc """
  Sends a completion request to Ollama with automatic failover.

  Returns:
  - `{:ok, response, server_url}` on success
  - `{:error, :all_instances_unavailable}` if all instances failed
  - `{:error, :total_timeout_exceeded}` if total timeout was reached
  - `{:error, term}` for non-retryable errors
  """
  @spec completion(completion_opts()) ::
          {:ok, map(), String.t()}
          | {:error, :all_instances_unavailable | :total_timeout_exceeded | term()}
  def completion(opts) do
    model = Keyword.get(opts, :model, default_model())
    prompt = Keyword.fetch!(opts, :prompt)
    images = Keyword.get(opts, :images, [])
    target_server = Keyword.get(opts, :target_server)

    instances = ollama_instances()
    total_timeout = AI.config(:ollama_total_timeout, 300_000)
    deadline = System.monotonic_time(:millisecond) + total_timeout

    instances_to_try = resolve_instances(instances, target_server)

    try_instances(instances_to_try, model, prompt, images, deadline, [])
  end

  @doc """
  Returns the list of configured Ollama instances.
  """
  def ollama_instances do
    case AI.config(:ollama_instances, nil) do
      instances when is_list(instances) ->
        instances

      nil ->
        url = AI.config(:ollama_url, "http://localhost:11434/api")
        timeout = AI.config(:ollama_timeout, 120_000)
        [%{url: url, timeout: timeout, priority: 1}]
    end
  end

  @doc """
  Returns the default model from feature flags or config.
  """
  def default_model do
    Animina.FeatureFlags.ollama_model()
  rescue
    _ -> "qwen3-vl:4b"
  end

  @doc """
  Returns instances to try, filtering by health status and sorting by priority.
  """
  @spec get_instances_to_try([map()], GenServer.server()) :: [map()]
  def get_instances_to_try(instances, tracker) do
    healthy_urls = HealthTracker.get_healthy_instances(tracker)

    healthy_instances =
      instances
      |> Enum.filter(fn inst -> inst.url in healthy_urls end)
      |> Enum.sort_by(& &1.priority)

    if healthy_instances == [] do
      Logger.warning("All AI circuits open, trying all instances as last resort")
      Enum.sort_by(instances, & &1.priority)
    else
      healthy_instances
    end
  end

  @spec calculate_request_timeout(map(), integer()) :: pos_integer()
  def calculate_request_timeout(instance, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)
    min(instance.timeout, max(remaining, 1000))
  end

  @spec failover_eligible_error?(term()) :: boolean()
  def failover_eligible_error?(error) when error in @failover_eligible_errors, do: true

  def failover_eligible_error?({:http_error, code}) when code in @failover_eligible_http_codes,
    do: true

  def failover_eligible_error?(_), do: false

  @spec parse_error(term()) :: term()
  def parse_error(%Mint.HTTPError{reason: {:status, code}}), do: {:http_error, code}
  def parse_error(%Mint.HTTPError{reason: reason}), do: reason
  def parse_error(error) when is_atom(error), do: error
  def parse_error(error), do: {:unknown, error}

  # --- Private Functions ---

  defp resolve_instances(instances, nil),
    do: get_instances_to_try(instances, HealthTracker)

  defp resolve_instances(instances, target_server) do
    case Enum.find(instances, fn inst -> inst.url == target_server end) do
      nil -> [%{url: target_server, timeout: AI.config(:ollama_timeout, 120_000), priority: 1}]
      inst -> [inst]
    end
  end

  defp try_instances([], _model, _prompt, _images, _deadline, errors) do
    Logger.error("All AI instances failed: #{inspect(errors)}")
    {:error, :all_instances_unavailable}
  end

  defp try_instances([instance | rest], model, prompt, images, deadline, errors) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      Logger.error("AI total timeout exceeded after #{length(errors)} attempt(s)")
      {:error, :total_timeout_exceeded}
    else
      timeout = calculate_request_timeout(instance, deadline)

      Logger.debug(
        "Trying AI instance #{instance.url} (priority: #{instance.priority}, timeout: #{timeout}ms)"
      )

      case do_request(instance.url, model, prompt, images, timeout) do
        {:ok, response} ->
          HealthTracker.record_success(instance.url)
          {:ok, response, instance.url}

        {:error, reason} ->
          parsed_error = parse_error(reason)
          HealthTracker.record_failure(instance.url, parsed_error)

          handle_request_error(
            instance,
            rest,
            model,
            prompt,
            images,
            deadline,
            errors,
            parsed_error
          )
      end
    end
  end

  defp handle_request_error(instance, rest, model, prompt, images, deadline, errors, parsed_error) do
    if failover_eligible_error?(parsed_error) do
      Logger.warning(
        "AI instance #{instance.url} failed with #{inspect(parsed_error)}, trying next"
      )

      try_instances(rest, model, prompt, images, deadline, [
        {instance.url, parsed_error} | errors
      ])
    else
      Logger.error("AI request failed with non-retryable error: #{inspect(parsed_error)}")
      {:error, parsed_error}
    end
  end

  defp do_request(url, model, prompt, images, timeout) do
    client = Ollama.init(base_url: url, receive_timeout: timeout)

    case Ollama.completion(client, model: model, prompt: prompt, images: images) do
      {:ok, %{"response" => response_text} = response} ->
        Logger.debug("AI response: #{inspect(response_text)}")
        {:ok, response}

      {:ok, unexpected} ->
        {:error, {:unexpected_response, unexpected}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
