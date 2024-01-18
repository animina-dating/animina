defmodule AniminaWeb.PageController do
  use AniminaWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def demo(conn, _params) do
    # Just a playground for testing things out.
    render(conn, :demo, layout: false)
  end
end
