defmodule Animina.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Animina.Servings

  @impl true
  def start(_type, _args) do
    children = [
      AniminaWeb.Telemetry,
      Animina.Repo,
      {DNSCluster, query: Application.get_env(:animina, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Animina.PubSub},

      # Start Oban
      {Oban,
       AshOban.config(
         Application.fetch_env!(:animina, :ash_apis),
         Application.fetch_env!(:animina, Oban)
       )},

      # Start the Finch HTTP client for sending emails
      {Finch, name: Animina.Finch},
      {Animina.GenServers.ProfileViewCredits, []},

      # Start a worker by calling: Animina.Worker.start_link(arg)
      # {Animina.Worker, arg},
      # Start to serve requests, typically the last entry
      AniminaWeb.Endpoint,
      {AshAuthentication.Supervisor, otp_app: :animina}
    ]

    children =
      if is_nil(System.get_env("ENABLE_ML_FEATURES")) do
        children
      else
        children ++
          [
            {Nx.Serving,
             name: NsfwDetectionServing,
             serving: Servings.NsfwDetectionServing.serving(),
             batch_timeout: 100}
          ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Animina.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AniminaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
