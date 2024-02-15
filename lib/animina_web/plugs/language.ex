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
        conn |> put_session("language", String.split(language, "-") |> Enum.at(0, "en"))

      [] ->
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
