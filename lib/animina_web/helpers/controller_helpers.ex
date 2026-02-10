defmodule AniminaWeb.Helpers.ControllerHelpers do
  @moduledoc """
  Shared helpers for Phoenix controllers.
  """

  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn, only: [get_req_header: 2]

  @doc """
  Redirects the user back to the referer URL, preserving query parameters.
  Falls back to "/" if no referer header is present.
  """
  def redirect_back(conn) do
    path =
      case get_req_header(conn, "referer") do
        [referer | _] ->
          uri = URI.parse(referer)
          base_path = uri.path || "/"

          if uri.query do
            "#{base_path}?#{uri.query}"
          else
            base_path
          end

        _ ->
          "/"
      end

    redirect(conn, to: path)
  end
end
