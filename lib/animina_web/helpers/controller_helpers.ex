defmodule AniminaWeb.Helpers.ControllerHelpers do
  @moduledoc """
  Shared helpers for Phoenix controllers.
  """

  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn, only: [get_req_header: 2, put_session: 3]

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

  @doc """
  Extracts connection metadata (user-agent and IP) for audit logging.
  """
  def conn_metadata(conn) do
    ua =
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> nil
      end

    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    %{"user_agent" => ua, "ip_address" => ip}
  end

  @doc """
  Sets user_return_to from sudo_return_to param (validates path starts with "/").
  """
  def maybe_set_sudo_return_to(conn, %{"sudo_return_to" => "/" <> _ = return_to}) do
    put_session(conn, :user_return_to, return_to)
  end

  def maybe_set_sudo_return_to(conn, _params), do: conn
end
