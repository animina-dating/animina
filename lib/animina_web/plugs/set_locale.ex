defmodule AniminaWeb.Plugs.SetLocale do
  @moduledoc """
  Plug that sets the locale for the current request.

  Priority order:
  1. Logged-in user's language preference (from DB)
  2. Session locale (previously set via language switcher)
  3. Accept-Language header
  4. Default locale ("de")
  """
  import Plug.Conn

  @supported_locales ~w(de en tr ru ar pl fr es uk)

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      user_locale(conn) ||
        get_session(conn, :locale) ||
        parse_accept_language(conn) ||
        default_locale()

    locale = if locale in @supported_locales, do: locale, else: default_locale()

    Gettext.put_locale(AniminaWeb.Gettext, locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end

  @doc """
  Returns the list of supported locale codes.
  """
  def supported_locales, do: @supported_locales

  defp user_locale(conn) do
    case conn.assigns do
      %{current_scope: %{user: %{language: lang}}} when is_binary(lang) -> lang
      _ -> nil
    end
  end

  defp parse_accept_language(conn) do
    case get_req_header(conn, "accept-language") do
      [header | _] -> best_match(header)
      _ -> nil
    end
  end

  defp best_match(header) do
    header
    |> String.split(",")
    |> Enum.map(&parse_language_tag/1)
    |> Enum.sort_by(fn {_lang, q} -> q end, :desc)
    |> Enum.find_value(fn {lang, _q} -> if lang in @supported_locales, do: lang end)
  end

  defp parse_language_tag(tag) do
    case String.split(String.trim(tag), ";") do
      [lang | rest] ->
        quality =
          case rest do
            ["q=" <> q | _] -> parse_quality(q)
            _ -> 1.0
          end

        # Extract primary language subtag (e.g., "en-US" -> "en")
        primary = lang |> String.trim() |> String.split("-") |> hd() |> String.downcase()
        {primary, quality}
    end
  end

  defp parse_quality(q) do
    case Float.parse(String.trim(q)) do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp default_locale do
    Application.get_env(:animina, AniminaWeb.Gettext, [])
    |> Keyword.get(:default_locale, "de")
  end
end
