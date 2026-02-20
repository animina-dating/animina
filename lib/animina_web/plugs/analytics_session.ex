defmodule AniminaWeb.Plugs.AnalyticsSession do
  @moduledoc """
  Plug that ensures an `analytics_session_id` UUID exists in the session.

  Generates a new UUID if one is not already present. This session ID
  is used to track anonymous page views across LiveView navigations.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, "analytics_session_id") do
      nil ->
        put_session(conn, "analytics_session_id", Ecto.UUID.generate())

      _existing ->
        conn
    end
  end
end
