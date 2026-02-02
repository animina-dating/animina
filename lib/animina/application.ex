defmodule Animina.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

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
        # Start to serve requests, typically the last entry
        AniminaWeb.Endpoint
      ] ++
        maybe_start_cleaner() ++
        maybe_start_scheduler() ++
        maybe_start_hot_deploy() ++
        maybe_start_online_users_logger()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Animina.Supervisor]
    Supervisor.start_link(children, opts)
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

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AniminaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
