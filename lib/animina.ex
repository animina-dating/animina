defmodule Animina do
  @moduledoc """
  Animina keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @compile_version Mix.Project.config()[:version]
  @compile_deployed_at DateTime.utc_now()

  def version do
    :persistent_term.get(:animina_version)
  rescue
    ArgumentError -> @compile_version
  end

  def deployed_at do
    :persistent_term.get(:animina_deployed_at)
  rescue
    ArgumentError -> @compile_deployed_at
  end

  def set_deploy_info(version, deployed_at) do
    :persistent_term.put(:animina_version, version)
    :persistent_term.put(:animina_deployed_at, deployed_at)
  end

  def initialize_deploy_info do
    :persistent_term.put(:animina_version, @compile_version)
    :persistent_term.put(:animina_deployed_at, @compile_deployed_at)
  end
end
