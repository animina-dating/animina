defmodule Animina.Photos.OllamaClient do
  @moduledoc """
  Unified Ollama client with cascading failover support.

  Tries configured Ollama instances in priority order, failing over to the
  next instance on connection errors or server issues. Uses circuit breaker
  pattern via OllamaHealthTracker to avoid repeatedly trying unhealthy instances.

  ## Failover Logic

  - Tries healthy instances (closed/half-open circuits) first, sorted by priority
  - If all circuits are open, tries all instances as a last resort
  - Respects total timeout across all attempts
  - Records successes/failures to health tracker for circuit breaker updates

  ## Error Classification

  Failover-eligible errors (try next instance):
  - Connection errors: econnrefused, timeout, closed, connect_timeout, ehostunreach
  - HTTP 502, 503, 504 (server errors)
  - HTTP 429 (rate limiting)

  Non-retryable errors (immediate failure):
  - HTTP 400, 404, 413 (client/request issues)
  - Other HTTP 4xx errors
  """

  require Logger

  alias Animina.Photos
  alias Animina.Photos.OllamaHealthTracker

  @type completion_opts :: [
          model: String.t(),
          prompt: String.t(),
          images: [String.t()],
          photo_id: String.t(),
          owner_id: String.t(),
          requester_id: String.t(),
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

  Options:
  - :model - Model name (default: from config)
  - :prompt - The prompt text (required)
  - :images - List of base64-encoded images (optional)

  Returns:
  - `{:ok, response, server_url}` on success (includes which server handled the request)
  - `{:error, :all_instances_unavailable}` if all instances failed
  - `{:error, :total_timeout_exceeded}` if total timeout was reached
  - `{:error, term}` for non-retryable errors
  """
  @spec completion(completion_opts()) ::
          {:ok, map(), String.t()}
          | {:error, :all_instances_unavailable | :total_timeout_exceeded | term()}
  def completion(opts) do
    model = Keyword.get(opts, :model, Photos.ollama_model())
    prompt = Keyword.fetch!(opts, :prompt)
    images = Keyword.get(opts, :images, [])
    photo_id = Keyword.get(opts, :photo_id)
    owner_id = Keyword.get(opts, :owner_id)
    requester_id = Keyword.get(opts, :requester_id)
    target_server = Keyword.get(opts, :target_server)

    # Create log entry with "in_progress" status BEFORE the call
    {:ok, log_entry} =
      Photos.create_ollama_log(%{
        photo_id: photo_id,
        owner_id: owner_id,
        requester_id: requester_id,
        prompt: prompt,
        model: model,
        status: "in_progress"
      })

    instances = Photos.ollama_instances()
    total_timeout = Photos.ollama_total_timeout()
    deadline = System.monotonic_time(:millisecond) + total_timeout

    instances_to_try = resolve_instances(instances, target_server)

    start_time = System.monotonic_time(:millisecond)
    result = try_instances(instances_to_try, model, prompt, images, deadline, [])
    duration_ms = System.monotonic_time(:millisecond) - start_time

    finalize_log_entry(log_entry, result, duration_ms)

    result
  end

  defp resolve_instances(instances, nil),
    do: get_instances_to_try(instances, OllamaHealthTracker)

  defp resolve_instances(instances, target_server) do
    case Enum.find(instances, fn inst -> inst.url == target_server end) do
      nil -> [%{url: target_server, timeout: Photos.ollama_timeout(), priority: 1}]
      inst -> [inst]
    end
  end

  defp finalize_log_entry(log_entry, result, duration_ms) do
    {status, response, server_url, error} =
      case result do
        {:ok, %{"response" => resp}, url} -> {"success", resp, url, nil}
        {:ok, resp, url} -> {"success", inspect(resp), url, nil}
        {:error, reason} -> {"error", nil, nil, inspect(reason)}
      end

    # Fire-and-forget — don't block the pipeline on logging
    Task.start(fn ->
      Photos.update_ollama_log(log_entry, %{
        result: response,
        duration_ms: duration_ms,
        server_url: server_url,
        status: status,
        error: error
      })
    end)
  end

  @doc """
  Returns instances to try, filtering by health status and sorting by priority.
  If all circuits are open, returns all instances as a last resort.
  """
  @spec get_instances_to_try([map()], GenServer.server()) :: [map()]
  def get_instances_to_try(instances, tracker) do
    healthy_urls = OllamaHealthTracker.get_healthy_instances(tracker)

    # Filter to healthy instances and sort by priority
    healthy_instances =
      instances
      |> Enum.filter(fn inst -> inst.url in healthy_urls end)
      |> Enum.sort_by(& &1.priority)

    # If no healthy instances, try all as last resort
    if healthy_instances == [] do
      Logger.warning("All Ollama circuits open, trying all instances as last resort")
      Enum.sort_by(instances, & &1.priority)
    else
      healthy_instances
    end
  end

  @doc """
  Calculates the timeout for a request, respecting both instance timeout
  and remaining time until total deadline.
  """
  @spec calculate_request_timeout(map(), integer()) :: pos_integer()
  def calculate_request_timeout(instance, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)
    # Use at least 1 second to give the request a chance
    min(instance.timeout, max(remaining, 1000))
  end

  @doc """
  Determines if an error should trigger failover to the next instance.
  """
  @spec failover_eligible_error?(term()) :: boolean()
  def failover_eligible_error?(error) when error in @failover_eligible_errors, do: true

  def failover_eligible_error?({:http_error, code}) when code in @failover_eligible_http_codes,
    do: true

  def failover_eligible_error?(_), do: false

  @doc """
  Parses an error into a normalized form for classification.
  """
  @spec parse_error(term()) :: term()
  def parse_error(%Mint.HTTPError{reason: {:status, code}}), do: {:http_error, code}
  def parse_error(%Mint.HTTPError{reason: reason}), do: reason
  def parse_error(error) when is_atom(error), do: error
  def parse_error(error), do: {:unknown, error}

  # --- Private Functions ---

  defp try_instances([], _model, _prompt, _images, _deadline, errors) do
    Logger.error("All Ollama instances failed: #{inspect(errors)}")
    {:error, :all_instances_unavailable}
  end

  defp try_instances([instance | rest], model, prompt, images, deadline, errors) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      Logger.error("Ollama total timeout exceeded after #{length(errors)} attempt(s)")
      {:error, :total_timeout_exceeded}
    else
      timeout = calculate_request_timeout(instance, deadline)

      Logger.debug(
        "Trying Ollama instance #{instance.url} (priority: #{instance.priority}, timeout: #{timeout}ms)"
      )

      case do_request(instance.url, model, prompt, images, timeout) do
        {:ok, response} ->
          OllamaHealthTracker.record_success(instance.url)
          {:ok, response, instance.url}

        {:error, reason} ->
          parsed_error = parse_error(reason)
          OllamaHealthTracker.record_failure(instance.url, parsed_error)

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
        "Ollama instance #{instance.url} failed with #{inspect(parsed_error)}, trying next"
      )

      try_instances(rest, model, prompt, images, deadline, [
        {instance.url, parsed_error} | errors
      ])
    else
      Logger.error("Ollama request failed with non-retryable error: #{inspect(parsed_error)}")

      {:error, parsed_error}
    end
  end

  defp do_request(url, model, prompt, images, timeout) do
    client = Ollama.init(base_url: url, receive_timeout: timeout)

    case Ollama.completion(client, model: model, prompt: prompt, images: images) do
      {:ok, %{"response" => response_text} = response} ->
        Logger.debug("Ollama response: #{inspect(response_text)}")
        {:ok, response}

      {:ok, unexpected} ->
        {:error, {:unexpected_response, unexpected}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
