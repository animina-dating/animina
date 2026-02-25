import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/animina start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :animina, AniminaWeb.Endpoint, server: true
end

config :animina, AniminaWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Ollama multi-instance configuration via environment variable
# Format: semicolons separate priority groups, commas separate instances within a group
# Optional @tags suffix per URL for instance-aware routing (default: gpu)
#   "gpu1,gpu2"               → both priority 1 (round-robin), tagged as gpu
#   "gpu1@gpu,gpu2@gpu;cpu@cpu" → GPUs priority 1, CPU priority 2 with tags
#   "url1;url2"               → strict failover (different priorities)
if ollama_urls = System.get_env("OLLAMA_URLS") do
  default_timeout = String.to_integer(System.get_env("OLLAMA_TIMEOUT", "120000"))

  instances =
    ollama_urls
    |> String.split(";")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {group, priority} ->
      group
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(fn raw ->
        {url, tags} =
          case String.split(raw, "@", parts: 2) do
            [url_part, tags_str] ->
              tag_list = tags_str |> String.split(",") |> Enum.map(&String.trim/1)
              {url_part, tag_list}

            [url_part] ->
              {url_part, ["gpu"]}
          end

        %{url: url, timeout: default_timeout, priority: priority, tags: tags}
      end)
    end)

  if instances != [] do
    config :animina, Animina.Photos, ollama_instances: instances
  end
end

if port = System.get_env("PROMETHEUS_NODE_EXPORTER_PORT") do
  config :animina, Animina.Monitoring.PrometheusClient,
    node_exporter_port: String.to_integer(port)
end

if config_env() == :prod do
  # Use a shared uploads directory that persists across releases
  upload_dir = System.get_env("UPLOAD_DIR", "/var/www/animina.de/shared/uploads")

  config :animina, Animina.Photos, upload_dir: upload_dir

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :animina, Animina.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :animina, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :animina, AniminaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base

  config :animina, Animina.HotDeploy,
    enabled: System.get_env("HOT_DEPLOY_ENABLED", "true") == "true",
    upgrades_dir: System.get_env("HOT_DEPLOY_DIR", "/var/www/animina.de/shared/hot-upgrades"),
    check_interval: String.to_integer(System.get_env("HOT_DEPLOY_INTERVAL", "10000"))

  # Mailer: use local Postfix via sendmail binary
  config :animina, Animina.Mailer,
    adapter: Swoosh.Adapters.Sendmail,
    cmd_path: "/usr/sbin/sendmail",
    cmd_args: "-N delay,failure,success",
    qmail: false

  # Monitor Postfix mail queue for delivery failures
  config :animina, start_mail_queue_checker: true

  # Monitor Postfix mail.log for bounce entries
  config :animina, start_mail_log_checker: true
end
