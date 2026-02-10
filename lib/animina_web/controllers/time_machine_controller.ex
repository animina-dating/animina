defmodule AniminaWeb.TimeMachineController do
  use AniminaWeb, :controller

  alias Animina.TimeMachine
  import AniminaWeb.Helpers.ControllerHelpers, only: [redirect_back: 1]

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
end
