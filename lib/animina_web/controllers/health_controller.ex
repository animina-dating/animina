defmodule AniminaWeb.HealthController do
  use AniminaWeb, :controller

  def index(conn, _params) do
    Ecto.Adapters.SQL.query!(Animina.Repo, "SELECT 1")
    json(conn, %{status: :ok})
  end
end
