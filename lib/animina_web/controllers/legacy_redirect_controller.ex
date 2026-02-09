defmodule AniminaWeb.LegacyRedirectController do
  @moduledoc """
  Handles 301 permanent redirects from legacy URL paths to their new locations.

  - `/users/settings` → `/my/settings`
  - `/users/settings/*` → `/my/settings/*`
  - `/moodboard/:user_id` → `/users/:user_id`
  """

  use AniminaWeb, :controller

  def settings_root(conn, _params) do
    url = append_query_string(conn, "/my/settings")

    conn
    |> put_status(301)
    |> redirect(to: url)
  end

  def settings(conn, %{"path" => path}) do
    new_path = "/my/settings/" <> Enum.join(path, "/")
    url = append_query_string(conn, new_path)

    conn
    |> put_status(301)
    |> redirect(to: url)
  end

  def moodboard(conn, %{"user_id" => user_id}) do
    url = append_query_string(conn, "/users/#{user_id}")

    conn
    |> put_status(301)
    |> redirect(to: url)
  end

  defp append_query_string(conn, path) do
    case conn.query_string do
      "" -> path
      qs -> path <> "?" <> qs
    end
  end
end
