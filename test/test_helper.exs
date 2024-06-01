# test/test_helper.exs
ExUnit.start()

if System.get_env("CI") do
  # Skip migrations and seeds in CI environment
  IO.puts("Running in CI environment. Skipping migrations and seeds.")
else
  # Run migrations and seeds locally
  Mix.Task.run("ecto.create", ["--quiet"])
  Mix.Task.run("ecto.migrate", ["--quiet"])
  Mix.Task.run("run", ["priv/repo/seeds.exs"])
end

Ecto.Adapters.SQL.Sandbox.mode(Animina.Repo, :manual)
