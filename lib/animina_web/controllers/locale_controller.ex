defmodule AniminaWeb.LocaleController do
  use AniminaWeb, :controller

  alias AniminaWeb.Plugs.SetLocale

  def update(conn, %{"locale" => locale}) do
    if locale in SetLocale.supported_locales() do
      Gettext.put_locale(AniminaWeb.Gettext, locale)

      if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
        user = conn.assigns.current_scope.user
        Animina.Accounts.update_user_language(user, locale, originator: user)
      end

      conn
      |> put_session(:locale, locale)
      |> redirect_back()
    else
      redirect_back(conn)
    end
  end

  def update(conn, _params) do
    redirect_back(conn)
  end

  defp redirect_back(conn) do
    path =
      case get_req_header(conn, "referer") do
        [referer | _] ->
          uri = URI.parse(referer)
          if uri.query, do: "#{uri.path || "/"}?#{uri.query}", else: uri.path || "/"

        _ ->
          "/"
      end

    redirect(conn, to: path)
  end
end
