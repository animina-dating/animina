# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :animina, :scopes,
  user: [
    default: true,
    module: Animina.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: Animina.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :animina,
  ecto_repos: [Animina.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :animina, AniminaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AniminaWeb.ErrorHTML, json: AniminaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Animina.PubSub,
  live_view: [signing_salt: "j4+hmLOO"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :animina, Animina.Mailer, adapter: Swoosh.Adapters.Local

# Central email sender configuration (address comes from FeatureFlags.support_email())
config :animina, :email_sender, name: "ANIMINA 👫❤️"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  animina: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  animina: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Quantum cron scheduler
config :animina, Animina.Scheduler,
  timezone: "Europe/Berlin",
  jobs: [
    {"0 0 * * *", {Animina.Accounts.DailyNewUsersReport, :run, []}},
    {"0 1 * * *", {Animina.Accounts, :purge_deleted_users, []}},
    {"0 6-20/2 * * *", {Animina.Accounts.RegistrationSpikeAlert, :run, []}},
    {"0 2 * * *", {Animina.Accounts, :purge_old_online_user_counts, []}},
    {"0 4 * * *", {Animina.Accounts.OnlineActivity, :purge_old_sessions, []}},
    {"0 * * * *", {Animina.Messaging.UnreadNotifier, :run, []}}
  ]

# Gettext i18n configuration
config :animina, AniminaWeb.Gettext,
  default_locale: "de",
  locales: ~w(de en tr ru ar pl fr es uk)

# PaperTrail audit trail
config :paper_trail,
  repo: Animina.Repo,
  item_type: Ecto.UUID,
  originator_type: Ecto.UUID,
  originator: [name: :user, model: Animina.Accounts.User],
  strict_mode: false

# Photo storage and processing configuration
config :animina, Animina.Photos,
  upload_dir: "uploads",
  max_upload_size: 10_000_000,
  max_dimension: 1200,
  thumbnail_dimension: 768,
  webp_quality: 80,
  # Ollama configuration - supports multiple instances with failover
  # If ollama_instances is not set, ollama_url is used as a single instance
  ollama_url: "http://localhost:11434/api",
  ollama_model: "qwen3-vl:8b",
  ollama_timeout: 120_000,
  ollama_total_timeout: 300_000,
  ollama_circuit_breaker_threshold: 3,
  # Example multi-instance config (uncomment to enable):
  # ollama_instances: [
  #   %{url: "http://localhost:11434/api", timeout: 120_000, priority: 1},
  #   %{url: "http://192.168.1.100:11434/api", timeout: 120_000, priority: 2}
  # ],
  ollama_circuit_breaker_reset_ms: 60_000

# Timezone database for proper CET/CEST handling
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# FunWithFlags feature flag library
config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: Animina.Repo

config :fun_with_flags, :cache,
  enabled: true,
  ttl: 900

config :fun_with_flags, :cache_bust_notifications, enabled: false

# WebAuthn / Passkey authentication (wax_ library)
# Environment-specific origin and rp_id are set in dev.exs, test.exs, and runtime.exs
config :wax_,
  rp_id: "animina.de",
  origin: "https://animina.de"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
