defmodule AniminaWeb.Plugs.AcceptLanguage do
  alias Plug.Conn

  @behaviour Plug

  @moduledoc """
  This is a module that creates a plug to intercept the request headers,
  extracts the *Accept-Language* header and injects it into the user's session
  """

  @locales Gettext.known_locales(AniminaWeb.Gettext)
  @cookie "Animinalanguage"

  defguard known_locale?(locale) when locale in @locales

  @impl Plug
  def init(_opts), do: nil

  @impl Plug
  def call(conn, _opts) do
    locale = fetch_locale(conn)

    conn
    |> Conn.assign(:language, locale)
    |> Conn.put_session(:language, locale)
  end

  defp fetch_locale(conn) do
    case locale_from_params(conn) || locale_from_cookies(conn) do
      nil ->
        # NOTE: This will fallback to the default locale set in `config.exs`
        Gettext.get_locale()

      locale ->
        locale
    end
  end

  defp locale_from_params(%Conn{params: %{"locale" => locale}})
       when known_locale?(locale) do
    locale
  end

  defp locale_from_params(_conn), do: nil

  defp locale_from_cookies(%Conn{cookies: %{@cookie => locale}})
       when known_locale?(locale) do
    locale
  end

  defp locale_from_cookies(_conn), do: nil
end
