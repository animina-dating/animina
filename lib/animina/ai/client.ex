defmodule Animina.AI.Client do
  @moduledoc """
  Unified Ollama client with round-robin load balancing and cascading failover.

  Instances are grouped by priority. Within each priority group, requests are
  distributed round-robin using an atomic counter. If the chosen instance fails,
  the request falls through to remaining instances in the group, then to lower-
  priority groups (overflow/failover).

  Supports instance filtering for job-type-aware routing (e.g., vision → GPU,
  text → CPU) via the `instance_filter` option.

  Uses circuit breaker pattern via HealthTracker to skip unhealthy instances.
  Does NOT create log entries — logging is at the Executor level via ai_jobs.
  """

  require Logger

  alias Animina.AI
  alias Animina.AI.HealthTracker

  @type completion_opts :: [
          model: String.t(),
          prompt: String.t(),
          images: [String.t()],
          target_server: String.t(),
          instance_filter: (map() -> boolean()),
          api_opts: keyword()
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
  - `:model` — model name (default from feature flags)
  - `:prompt` — the prompt text (required)
  - `:images` — list of base64-encoded images
  - `:target_server` — pin to a specific server URL
  - `:instance_filter` — function `(instance_map) -> boolean` to pre-filter instances
  - `:api_opts` — extra keyword options passed through to `Ollama.completion/2` (e.g. `think: false`)

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
    instance_filter = Keyword.get(opts, :instance_filter)
    api_opts = Keyword.get(opts, :api_opts, [])

    instances = ollama_instances()
    total_timeout = AI.config(:ollama_total_timeout, 300_000)
    deadline = System.monotonic_time(:millisecond) + total_timeout

    instances_to_try = resolve_instances(instances, target_server, instance_filter)
    req = %{model: model, prompt: prompt, images: images, api_opts: api_opts}

    try_instances(instances_to_try, req, deadline, [])
  end

  @doc """
  Returns the list of configured Ollama instances.
  """
  def ollama_instances do
    default_tags = AI.config(:ollama_default_tags, ["gpu"])

    case AI.config(:ollama_instances, nil) do
      instances when is_list(instances) ->
        Enum.map(instances, fn inst ->
          Map.put_new(inst, :tags, default_tags)
        end)

      nil ->
        url = AI.config(:ollama_url, "http://localhost:11434/api")
        timeout = AI.config(:ollama_timeout, 120_000)
        [%{url: url, timeout: timeout, priority: 1, tags: default_tags}]
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
  Returns instances to try, filtering by health status, sorting by priority,
  and applying round-robin rotation within each priority group.
  """
  @spec get_instances_to_try([map()], GenServer.server()) :: [map()]
  def get_instances_to_try(instances, tracker) do
    healthy_urls = HealthTracker.get_healthy_instances(tracker)

    healthy_instances =
      instances
      |> Enum.filter(fn inst -> inst.url in healthy_urls end)
      |> Enum.sort_by(& &1.priority)

    candidates =
      if healthy_instances == [] do
        Logger.warning("All AI circuits open, trying all instances as last resort")
        Enum.sort_by(instances, & &1.priority)
      else
        healthy_instances
      end

    rotate_instances(candidates, next_counter())
  end

  @doc """
  Initializes the atomic counter for round-robin distribution.
  Called once during application startup.
  """
  def init_counter do
    counter = :atomics.new(1, signed: false)
    :persistent_term.put({__MODULE__, :counter}, counter)
    :ok
  end

  @doc """
  Rotates instances within each priority group using the given counter value.
  Higher-priority groups (lower number) come first. Within each group,
  instances are rotated so different requests start with different instances.

  Public for testability.
  """
  @spec rotate_instances([map()], non_neg_integer()) :: [map()]
  def rotate_instances(instances, counter) do
    instances
    |> Enum.group_by(& &1.priority)
    |> Enum.sort_by(fn {priority, _} -> priority end)
    |> Enum.flat_map(fn {_priority, group} ->
      len = length(group)

      if len <= 1 do
        group
      else
        offset = rem(counter, len)
        Enum.drop(group, offset) ++ Enum.take(group, offset)
      end
    end)
  end

  defp next_counter do
    counter = :persistent_term.get({__MODULE__, :counter}, nil)

    if counter do
      :atomics.add_get(counter, 1, 1)
    else
      0
    end
  rescue
    _ -> 0
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

  defp resolve_instances(instances, nil, nil),
    do: get_instances_to_try(instances, HealthTracker)

  defp resolve_instances(instances, nil, filter) when is_function(filter, 1) do
    filtered = Enum.filter(instances, filter)

    if filtered == [] do
      # Fall back to all instances if filter eliminates everything
      Logger.debug("Instance filter matched no instances, falling back to all")
      get_instances_to_try(instances, HealthTracker)
    else
      get_instances_to_try(filtered, HealthTracker)
    end
  end

  defp resolve_instances(instances, target_server, _filter) do
    case Enum.find(instances, fn inst -> inst.url == target_server end) do
      nil ->
        [
          %{
            url: target_server,
            timeout: AI.config(:ollama_timeout, 120_000),
            priority: 1,
            tags: ["gpu"]
          }
        ]

      inst ->
        [inst]
    end
  end

  defp try_instances([], _req, _deadline, errors) do
    Logger.error("All AI instances failed: #{inspect(errors)}")
    {:error, :all_instances_unavailable}
  end

  defp try_instances([instance | rest], req, deadline, errors) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      Logger.error("AI total timeout exceeded after #{length(errors)} attempt(s)")
      {:error, :total_timeout_exceeded}
    else
      timeout = calculate_request_timeout(instance, deadline)

      Logger.debug(
        "Trying AI instance #{instance.url} (priority: #{instance.priority}, timeout: #{timeout}ms, tags: #{inspect(Map.get(instance, :tags, []))})"
      )

      start_ms = System.monotonic_time(:millisecond)

      case do_request(instance.url, req, timeout) do
        {:ok, response} ->
          duration_ms = System.monotonic_time(:millisecond) - start_ms
          HealthTracker.record_success(instance.url, duration_ms)
          {:ok, response, instance.url}

        {:error, reason} ->
          handle_request_error(instance, rest, req, deadline, errors, reason)
      end
    end
  end

  defp handle_request_error(instance, rest, req, deadline, errors, reason) do
    parsed_error = parse_error(reason)
    HealthTracker.record_failure(instance.url, parsed_error)

    if failover_eligible_error?(parsed_error) do
      Logger.warning(
        "AI instance #{instance.url} failed with #{inspect(parsed_error)}, trying next"
      )

      try_instances(rest, req, deadline, [{instance.url, parsed_error} | errors])
    else
      Logger.error("AI request failed with non-retryable error: #{inspect(parsed_error)}")
      {:error, parsed_error}
    end
  end

  defp do_request(
         url,
         %{model: model, prompt: prompt, images: images, api_opts: api_opts},
         timeout
       ) do
    client = Ollama.init(base_url: url, receive_timeout: timeout)

    base_opts = [model: model, prompt: prompt, images: images]

    case Ollama.completion(client, Keyword.merge(base_opts, api_opts)) do
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
