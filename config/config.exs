# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

if System.get_env("DISABLE_ML_FEATURES") == true do
  # Configures nx default backend
  config :nx, default_backend: EXLA.Backend
end

# Configures the environment

config :animina, env: Mix.env()

# configures the maximum number of users allowed to the system within the hour before joining the waiting list

config :animina, :max_users_per_hour, 100

# Configures the number of stories required for complete registration
config :animina, :number_of_stories_required_for_complete_registration, 1

# Configures the minimum number of points required to view the 'AI Help' Chat Message in the chat
config :animina, :ai_message_help_price, 20

config :animina,
  ecto_repos: [Animina.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :animina, AniminaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: AniminaWeb.ErrorHTML, json: AniminaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Animina.PubSub,
  live_view: [signing_salt: "firBsg4T"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :animina, Animina.Mailer, adapter: Swoosh.Adapters.Local

config :animina,
  ash_domains: [Animina.Accounts, Animina.Traits, Animina.GeoData, Animina.Narratives]

config :ash, :custom_types, ash_phone_number: Animina.AshPhoneNumber

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.1",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# I18n
config :animina, AniminaWeb.Gettext, default_locale: "en", locales: ~w(de en)

config :animina, AniminaWeb.FlagsLive, max_selected: 20

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [section_order: [:resources, :policies, :authorization, :domain, :execution]]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
