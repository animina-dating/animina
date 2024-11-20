defmodule Animina.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :animina

  alias Ecto.Adapters.Postgres
  alias Ecto.Migrator

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :up, all: true))
    end
  end

  def reset do
    load_app()

    for repo <- repos() do
      Postgres.storage_down(repo.config())
      Postgres.storage_up(repo.config())
    end

    migrate()
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
