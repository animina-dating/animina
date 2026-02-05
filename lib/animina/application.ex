defmodule Animina.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Animina.Photos.OllamaWarmup
  alias Animina.Photos.PhotoProcessor

  @impl true
  def start(_type, _args) do
    # Reapply any pending hot code upgrade from a previous deploy
    Animina.HotDeploy.startup_reapply_current()

    children =
      [
        AniminaWeb.Telemetry,
        Animina.Repo,
        {DNSCluster, query: Application.get_env(:animina, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Animina.PubSub},
        AniminaWeb.Presence,
        # Debug store for Ollama calls (always started, but only logs when flag enabled)
        Animina.FeatureFlags.OllamaDebugStore,
        # Start to serve requests, typically the last entry
        AniminaWeb.Endpoint
      ] ++
        maybe_start_cleaner() ++
        maybe_start_scheduler() ++
        maybe_start_hot_deploy() ++
        maybe_start_online_users_logger() ++
        maybe_start_ollama_health_tracker() ++
        maybe_start_photo_processor() ++
        maybe_start_ollama_retry_scheduler()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Animina.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Initialize feature flags after Repo is ready
    initialize_feature_flags()

    # Recover stuck photos after services are ready (delayed to ensure GenServers are up)
    recover_stuck_photos()

    # Warm up Ollama model (delayed to ensure OllamaHealthTracker is ready)
    warmup_ollama()

    result
  end

  defp warmup_ollama do
    if Application.get_env(:animina, :start_photo_processor, true) do
      Task.start(fn ->
        # Wait for OllamaHealthTracker GenServer to be fully initialized
        Process.sleep(2000)
        OllamaWarmup.warmup_all()
      end)
    end
  end

  defp recover_stuck_photos do
    if Application.get_env(:animina, :start_photo_processor, true) do
      # Spawn a task to recover stuck photos after a short delay
      # This ensures the PhotoProcessor GenServer is fully started
      Task.start(fn ->
        Process.sleep(1000)
        PhotoProcessor.recover_stuck_photos()
      end)
    end
  end

  defp initialize_feature_flags do
    # Enable all photo processing flags by default for safety
    Animina.FeatureFlags.initialize_photo_flags()
    # Initialize system settings with defaults
    Animina.FeatureFlags.initialize_system_settings()
    # Initialize ollama settings (flags and values)
    Animina.FeatureFlags.initialize_ollama_settings()
    # Initialize admin flags (disabled by default)
    Animina.FeatureFlags.initialize_admin_flags()
  rescue
    # Don't crash on startup if this fails (e.g., during migrations)
    _ -> :ok
  end

  defp maybe_start_cleaner do
    if Application.get_env(:animina, :start_unconfirmed_user_cleaner, true) do
      [Animina.Accounts.UnconfirmedUserCleaner]
    else
      []
    end
  end

  defp maybe_start_scheduler do
    if Application.get_env(:animina, :start_scheduler, true) do
      [Animina.Scheduler]
    else
      []
    end
  end

  defp maybe_start_hot_deploy do
    config = Application.get_env(:animina, Animina.HotDeploy, [])

    if config[:enabled] do
      [Animina.HotDeploy]
    else
      []
    end
  end

  defp maybe_start_online_users_logger do
    if Application.get_env(:animina, :start_online_users_logger, true) do
      [Animina.Accounts.OnlineUsersLogger]
    else
      []
    end
  end

  defp maybe_start_ollama_health_tracker do
    if Application.get_env(:animina, :start_photo_processor, true) do
      [Animina.Photos.OllamaHealthTracker]
    else
      []
    end
  end

  defp maybe_start_photo_processor do
    if Application.get_env(:animina, :start_photo_processor, true) do
      [Animina.Photos.PhotoProcessor]
    else
      []
    end
  end

  defp maybe_start_ollama_retry_scheduler do
    if Application.get_env(:animina, :start_photo_processor, true) do
      [Animina.Photos.OllamaRetryScheduler]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AniminaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
