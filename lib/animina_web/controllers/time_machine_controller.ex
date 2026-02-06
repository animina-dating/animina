defmodule AniminaWeb.TimeMachineController do
  use AniminaWeb, :controller

  alias Animina.TimeMachine

  def add_hours(conn, %{"hours" => hours}) do
    {n, _} = Integer.parse(hours)
    TimeMachine.add_hours(n)
    redirect_back(conn)
  end

  def add_days(conn, %{"days" => days}) do
    {n, _} = Integer.parse(days)
    TimeMachine.add_days(n)
    redirect_back(conn)
  end

  def reset(conn, _params) do
    TimeMachine.reset()
    redirect_back(conn)
  end

  defp redirect_back(conn) do
    path =
      case get_req_header(conn, "referer") do
        [referer | _] ->
          uri = URI.parse(referer)
          uri.path || "/"

        _ ->
          "/"
      end

    redirect(conn, to: path)
  end
end
