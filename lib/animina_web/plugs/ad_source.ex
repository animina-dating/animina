defmodule AniminaWeb.Plugs.AdSource do
  @moduledoc """
  Plug that reads the ad source cookie and puts it into the session.

  This runs on every browser request so that LiveViews can access
  the `ad_source_id` from the session during mount.
  """

  import Plug.Conn

  @ad_source_cookie "_animina_ad_source"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn, signed: [@ad_source_cookie])

    case conn.cookies[@ad_source_cookie] do
      nil ->
        conn

      ad_id when is_binary(ad_id) ->
        put_session(conn, "ad_source_id", ad_id)

      _ ->
        conn
    end
  end
end
