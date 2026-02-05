defmodule Animina.Photos.OllamaWarmup do
  @moduledoc """
  Warms up Ollama by preloading the configured model at application startup.

  Ollama loads models into GPU/memory on first use. By sending a minimal request
  with a long `keep_alive` at startup, we ensure the model is loaded before real
  traffic arrives, avoiding the slow first-request penalty.
  """

  require Logger

  alias Animina.Photos
  alias Animina.Photos.OllamaHealthTracker

  @doc """
  Warms up all configured Ollama instances by sending a minimal prompt.

  Returns :ok regardless of success/failure (warmup is best-effort).
  """
  @spec warmup_all() :: :ok
  def warmup_all do
    model = Photos.ollama_model()
    instances = Photos.ollama_instances()

    Logger.info("Ollama warmup: loading #{model} on #{length(instances)} instance(s)")

    Enum.each(instances, fn instance ->
      warmup_instance(instance.url, model, instance.timeout)
    end)

    :ok
  end

  defp warmup_instance(url, model, timeout) do
    # Cap warmup timeout at 2 minutes to avoid blocking too long
    warmup_timeout = min(timeout, 120_000)
    client = Ollama.init(base_url: url, receive_timeout: warmup_timeout)

    case Ollama.completion(client, model: model, prompt: "hi", keep_alive: "60m") do
      {:ok, _} ->
        Logger.info("Ollama warmup: #{url} ready")
        OllamaHealthTracker.record_success(url)

      {:error, reason} ->
        Logger.warning("Ollama warmup failed for #{url}: #{inspect(reason)}")
        OllamaHealthTracker.record_failure(url, reason)
    end
  end
end
