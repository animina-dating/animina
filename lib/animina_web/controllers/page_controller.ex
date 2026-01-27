defmodule AniminaWeb.PageController do
  use AniminaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
