defmodule Animina.AI.Client do
  @moduledoc """
  Simple Ollama HTTP client.

  Sends requests to a specific Ollama instance URL. One retry with 2s sleep
  on transient errors. No round-robin or circuit breaker — the Queue handles
  instance selection.
  """

  require Logger

  @retryable_errors [
    :econnrefused,
    :timeout,
    :closed,
    :connect_timeout,
    :ehostunreach,
    :enetunreach,
    :enotconn,
    :connection_closed
  ]

  @retryable_http_codes [429, 500, 502, 503, 504]

  @doc """
  Sends a completion request to a specific Ollama instance.

  Options:
  - `:url` — Ollama instance base URL (required)
  - `:model` — model name (required)
  - `:prompt` — the prompt text (required)
  - `:images` — list of base64-encoded images
  - `:timeout` — request timeout in ms (default: 120_000)
  - `:api_opts` — extra keyword options passed through to `Ollama.completion/2`

  Returns `{:ok, response_text, duration_ms}` or `{:error, reason}`.
  """
  def completion(opts) do
    url = Keyword.fetch!(opts, :url)
    model = Keyword.fetch!(opts, :model)
    prompt = Keyword.fetch!(opts, :prompt)
    images = Keyword.get(opts, :images, [])
    timeout = Keyword.get(opts, :timeout, 120_000)
    api_opts = Keyword.get(opts, :api_opts, [])

    case do_request(url, model, prompt, images, timeout, api_opts) do
      {:ok, _response_text, _duration_ms} = success ->
        success

      {:error, reason} ->
        if retryable?(reason) do
          Logger.warning("AI Client: retrying after #{inspect(reason)} (2s sleep)")
          Process.sleep(2_000)
          do_request(url, model, prompt, images, timeout, api_opts)
        else
          {:error, reason}
        end
    end
  end

  @doc """
  Preloads a model on a specific Ollama instance.
  """
  def warmup(url, model) do
    client = Ollama.init(base_url: url, receive_timeout: 30_000)

    case Ollama.completion(client, model: model, prompt: "warmup", keep_alive: "10m") do
      {:ok, _} ->
        Logger.info("AI Client: warmed up #{model} on #{url}")
        :ok

      {:error, reason} ->
        Logger.warning("AI Client: warmup failed for #{model} on #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Returns the list of configured Ollama instances from app config.
  """
  def parse_instances do
    default_tags = config(:ollama_default_tags, ["gpu"])

    case config(:ollama_instances, nil) do
      instances when is_list(instances) ->
        Enum.map(instances, fn inst ->
          Map.put_new(inst, :tags, default_tags)
        end)

      nil ->
        url = config(:ollama_url, "http://localhost:11434/api")
        timeout = config(:ollama_timeout, 120_000)
        [%{url: url, timeout: timeout, tags: default_tags}]
    end
  end

  # --- Private ---

  defp do_request(url, model, prompt, images, timeout, api_opts) do
    client = Ollama.init(base_url: url, receive_timeout: timeout)
    base_opts = [model: model, prompt: prompt, images: images]
    start_ms = System.monotonic_time(:millisecond)

    case Ollama.completion(client, Keyword.merge(base_opts, api_opts)) do
      {:ok, %{"response" => response_text}} ->
        duration_ms = System.monotonic_time(:millisecond) - start_ms
        {:ok, response_text, duration_ms}

      {:ok, unexpected} ->
        {:error, {:unexpected_response, unexpected}}

      {:error, reason} ->
        {:error, parse_error(reason)}
    end
  end

  defp retryable?(error) when error in @retryable_errors, do: true
  defp retryable?({:http_error, code}) when code in @retryable_http_codes, do: true
  defp retryable?(_), do: false

  defp parse_error(%Mint.HTTPError{reason: {:status, code}}), do: {:http_error, code}
  defp parse_error(%Mint.HTTPError{reason: reason}), do: reason
  defp parse_error(error) when is_atom(error), do: error
  defp parse_error(error), do: {:unknown, error}

  @doc """
  Reads AI/Ollama config from the `:animina, Animina.Photos` app env.

  Legacy location — config lives under `Animina.Photos` for historical reasons.
  """
  def config(key, default) do
    :animina
    |> Application.get_env(Animina.Photos, [])
    |> Keyword.get(key, default)
  end
end
