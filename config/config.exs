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

# Central email sender configuration
config :animina, :email_sender,
  name: "ANIMINA 👫❤️",
  address: "noreply@animina.de"

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
    {"0 0 * * *", {Animina.Accounts.DailyNewUsersReport, :run, []}}
  ]

# Gettext i18n configuration
config :animina, AniminaWeb.Gettext,
  default_locale: "de",
  locales: ~w(de en tr ru ar pl fr es uk)

# Timezone database for proper CET/CEST handling
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
