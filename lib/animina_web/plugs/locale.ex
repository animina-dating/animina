defmodule AniminaWeb.Plugs.Locale do
  @moduledoc """
  This is a module that creates a plug to intercept the request headers,
  extracts the *Accept-Language* header and injects it into the user's session.
  It also checks the locale from cookies and params.
  """
  @locales Gettext.known_locales(AniminaWeb.Gettext)
  import Plug.Conn
  alias Plug.Conn

  def init(_opts), do: nil

  def call(conn, _opts) do
    case locale_from_params(conn) || locale_from_cookies(conn) || locale_from_header(conn) do
      nil ->
        conn
        |> Conn.assign(:language, Gettext.get_locale())
        |> Conn.put_session(:language, Gettext.get_locale())

      locale ->
        Gettext.put_locale(AniminaWeb.Gettext, locale)
        conn = conn |> persist_locale(locale)

        conn
        |> Conn.assign(:language, locale)
        |> Conn.put_session(:language, locale)
    end
  end

  defp persist_locale(conn, new_locale) do
    if conn.cookies["locale"] != new_locale do
      conn |> put_resp_cookie("locale", new_locale, max_age: 10 * 24 * 60 * 60)
    else
      conn
    end
  end

  defp locale_from_params(conn) do
    conn.params["locale"] |> validate_locale
  end

  defp locale_from_cookies(conn) do
    conn.cookies["locale"] |> validate_locale
  end

  defp locale_from_header(conn) do
    conn
    |> extract_accept_language
    |> Enum.find(nil, fn accepted_locale -> Enum.member?(@locales, accepted_locale) end)
  end

  def extract_accept_language(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> Enum.map(&parse_language_option/1)
        |> Enum.sort(&(&1.quality > &2.quality))
        |> Enum.map(& &1.tag)
        |> Enum.reject(&is_nil/1)
        |> ensure_language_fallbacks()

      _ ->
        []
    end
  end

  defp parse_language_option(string) do
    captures = Regex.named_captures(~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i, string)

    quality =
      case Float.parse(captures["quality"] || "1.0") do
        {val, _} -> val
        _ -> 1.0
      end

    %{tag: captures["tag"], quality: quality}
  end

  defp ensure_language_fallbacks(tags) do
    Enum.flat_map(tags, fn tag ->
      [language | _] = String.split(tag, "-")
      if Enum.member?(tags, language), do: [tag], else: [tag, language]
    end)
  end

  defp validate_locale(locale) when locale in @locales, do: locale
  defp validate_locale(_locale), do: nil
end
