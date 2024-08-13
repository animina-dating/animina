defmodule Animina.MixProject do
  use Mix.Project

  def project do
    [
      app: :animina,
      version: "0.2.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  #
  def application do
    [
      mod: {Animina.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  #
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  #
  defp deps do
    deps = [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.9"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:gen_smtp, "~> 1.2", only: :prod},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:plug_cowboy, "~> 2.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ash, "~> 3.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~>  2.0"},
      {:ash_postgres, "~> 2.0"},
      {:size, "~> 0.1.0"},
      {:ash_state_machine, "~> 0.2.2"},
      {:ex_phone_number, "~> 0.4.3"},
      {:httpoison, "~> 2.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:faker, "~> 0.18", only: [:dev, :test]},
      {:mdex, "~> 0.1"},
      {:html_sanitize_ex, "~> 1.4"},
      {:timex, "~> 3.0"},
      {:oban, "~> 2.17"},
      {:ash_oban, "~> 0.2.2"},
      {:mogrify, "~> 0.9.3"},
      {:briefly, "~> 0.5.0"},
      {:gen_stage, "~> 1.2.1"}
    ]

    if System.get_env("DISABLE_ML_FEATURES") do
      deps
    else
      deps ++
        [
          {:bumblebee, "~> 0.5.3"},
          {:exla, ">= 0.0.0"},
          {:stb_image, "~> 0.6.3"}
        ]
    end
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  #
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      "ash_postgres.reset": ["ash_postgres.drop", "ash_postgres.create", "ash_postgres.migrate"]
    ]
  end
end
