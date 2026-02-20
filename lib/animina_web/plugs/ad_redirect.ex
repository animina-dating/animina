defmodule AniminaWeb.Plugs.AdRedirect do
  @moduledoc """
  Plug that handles ad campaign redirect URLs.

  Matches `GET /` with `?ad=<code>` query param, logs the visit,
  sets a signed cookie for conversion tracking, and redirects to `/`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Animina.Ads
  alias Animina.Ads.Ad
  alias Animina.Ads.UserAgentParser
  alias Animina.TimeMachine

  @ad_source_cookie "_animina_ad_source"
  @cookie_max_age 30 * 24 * 60 * 60

  def init(opts), do: opts

  def call(%{method: "GET", request_path: "/"} = conn, _opts) do
    conn = fetch_query_params(conn)

    case conn.query_params do
      %{"ad" => code} ->
        handle_ad_redirect(conn, code)

      _ ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp handle_ad_redirect(conn, code) do
    with {number, ""} <- Integer.parse(code, 36),
         %Ad{} = ad <- Ads.get_ad_by_number(number) do
      if Ad.active?(ad), do: log_ad_visit(conn, ad)

      conn
      |> put_resp_cookie(@ad_source_cookie, ad.id,
        sign: true,
        max_age: @cookie_max_age,
        http_only: true,
        same_site: "Lax"
      )
      |> redirect(to: "/")
      |> halt()
    else
      nil ->
        # Ad number doesn't exist — still redirect (URL was from an ad)
        conn |> redirect(to: "/") |> halt()

      _ ->
        # Invalid code — pass through to normal IndexLive
        conn
    end
  end

  defp log_ad_visit(conn, ad) do
    ua_string = get_ua_header(conn)
    parsed = UserAgentParser.parse(ua_string)
    language = UserAgentParser.parse_language(get_accept_language(conn))

    Ads.log_visit(ad, %{
      ip_address: format_ip(conn.remote_ip),
      user_agent: truncate(ua_string, 500),
      referer: truncate(get_referer(conn), 500),
      os: parsed.os,
      browser: parsed.browser,
      device_type: parsed.device_type,
      device_model: parsed.device_model,
      is_bot: parsed.is_bot,
      language: language,
      visited_at: TimeMachine.utc_now(:second)
    })
  end

  defp get_ua_header(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      _ -> nil
    end
  end

  defp get_referer(conn) do
    case get_req_header(conn, "referer") do
      [ref | _] -> ref
      _ -> nil
    end
  end

  defp get_accept_language(conn) do
    case get_req_header(conn, "accept-language") do
      [lang | _] -> lang
      _ -> nil
    end
  end

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(ip), do: to_string(ip)

  defp truncate(nil, _max), do: nil
  defp truncate(str, max) when byte_size(str) > max, do: String.slice(str, 0, max)
  defp truncate(str, _max), do: str
end
