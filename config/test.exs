import Config

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
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :animina, AniminaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "g4khw+AmYhM1wjVIOksjBXR6Tf9xK2d2v+Q+Hc0dt15oF0hQHk/b/TaBVOBMfBD4",
  server: false

# In test we don't send emails.
config :animina, Animina.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# configures the maximum number of users allowed to the system within the hour before joining the waiting list

config :animina, :max_users_per_hour, 5

# configures the number of days behind we check when showing users on the sidebar for potential partners

config :animina, :number_of_days_to_filter_registered_users, 60

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :animina, Oban, testing: :manual

config :animina, :environment, :test
