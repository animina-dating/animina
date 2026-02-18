defmodule Animina.AI.Warmup do
  @moduledoc """
  Warms up Ollama by preloading models at application startup.

  Ollama loads models into GPU/memory on first use. By sending a minimal request
  with a long `keep_alive` at startup, we ensure models are loaded before real
  traffic arrives, avoiding the slow first-request penalty.

  Instance-tag-aware: GPU instances warm all tier models (for adaptive quality
  selection). CPU instances only warm the smallest vision + text models.
  """

  require Logger

  alias Animina.AI.Client
  alias Animina.AI.HealthTracker
  alias Animina.FeatureFlags

  # Models suitable for CPU instances (small enough for no-GPU inference)
  @cpu_vision_model "qwen3-vl:2b"
  @cpu_text_model "qwen3:1.7b"

  @doc """
  Warms up all configured Ollama instances by sending a minimal prompt.

  GPU instances get all tier models loaded. CPU instances get only the
  smallest vision + text models to avoid memory pressure.

  Returns :ok regardless of success/failure (warmup is best-effort).
  """
  @spec warmup_all() :: :ok
  def warmup_all do
    instances = Client.ollama_instances()

    Enum.each(instances, fn instance ->
      tags = Map.get(instance, :tags, ["gpu"])
      models = models_for_instance(tags)

      Logger.info(
        "AI warmup: loading #{Enum.join(models, ", ")} on #{instance.url} (tags: #{inspect(tags)})"
      )

      Enum.each(models, fn model ->
        warmup_instance(instance.url, model, instance.timeout)
      end)
    end)

    :ok
  end

  defp models_for_instance(tags) do
    if "cpu" in tags do
      # CPU instances: only load smallest models
      Enum.uniq([@cpu_vision_model, @cpu_text_model])
    else
      # GPU instances: load all tier models for adaptive selection
      gpu_models()
    end
  end

  defp gpu_models do
    primary = Client.default_model()

    if FeatureFlags.enabled?(:ollama_adaptive_model) do
      tier1 = FeatureFlags.ollama_model_tier1()
      tier2 = FeatureFlags.ollama_model_tier2()
      tier3 = FeatureFlags.ollama_model_tier3()
      Enum.uniq([tier1, tier2, tier3])
    else
      [primary]
    end
  rescue
    _ -> [Client.default_model()]
  end

  defp warmup_instance(url, model, timeout) do
    warmup_timeout = min(timeout, 120_000)
    client = Ollama.init(base_url: url, receive_timeout: warmup_timeout)

    case Ollama.completion(client, model: model, prompt: "hi", keep_alive: "60m") do
      {:ok, _} ->
        Logger.info("AI warmup: #{url} ready with #{model}")
        HealthTracker.record_success(url)

      {:error, reason} ->
        Logger.warning("AI warmup failed for #{url} with #{model}: #{inspect(reason)}")
        HealthTracker.record_failure(url, reason)
    end
  end
end
