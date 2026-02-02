import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :animina, Animina.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "animina_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :animina, AniminaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "hlzKzhRnwmpFJlvi78wEVQxc5bK9AKe9fW6qH0HrF3j/rKl3DnimjM0/pilUq9xa",
  server: false

# In test we don't send emails
config :animina, Animina.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Disable the unconfirmed user cleaner GenServer in tests
config :animina, start_unconfirmed_user_cleaner: false

# Disable the Quantum scheduler in tests
config :animina, start_scheduler: false

# Disable the online users logger GenServer in tests
config :animina, start_online_users_logger: false

# Use English locale in tests so assertions match English msgid strings
config :animina, AniminaWeb.Gettext, default_locale: "en"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
