defmodule Animina do
  @moduledoc """
  Animina keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @version Mix.Project.config()[:version]
  @deployed_at DateTime.utc_now()

  def version, do: @version
  def deployed_at, do: @deployed_at
end
