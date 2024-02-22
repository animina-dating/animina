defmodule AniminaWeb.Plugs.AcceptLanguage do
  import Plug.Conn

  @moduledoc """
  This is a module that creates a plug to intercept the request headers,
  extracts the *Accept-Language* header and injects it into the user's session
  """

  def init(options), do: options

  def call(conn, _options) do
    conn
    |> extract_accept_language()
    |> case do
      [language | _] ->
        case parse_language(language) |> supported_locale?() do
          true -> Gettext.put_locale(AniminaWeb.Gettext, parse_language(language))
          _ -> Gettext.put_locale(AniminaWeb.Gettext, "en")
        end

        conn |> put_session("language", language)

      [] ->
        Gettext.put_locale(AniminaWeb.Gettext, "en")
        conn |> put_session("language", "en")
    end
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

  defp supported_locales,
    do: Gettext.known_locales(AniminaWeb.Gettext) ++ ["de"]

  defp supported_locale?(locale), do: Enum.member?(supported_locales(), locale)

  defp parse_language(language) do
    case language do
      "de-" <> _rest -> "de"
      "en-" <> _rest -> "en"
      _ -> language
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
end
