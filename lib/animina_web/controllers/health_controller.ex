defmodule AniminaWeb.HealthController do
  use AniminaWeb, :controller

  alias Ecto.Adapters.SQL

  def index(conn, _params) do
    SQL.query!(Animina.Repo, "SELECT 1")
    json(conn, %{status: :ok})
  end
end
