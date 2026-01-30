defmodule AniminaWeb.LocaleController do
  use AniminaWeb, :controller

  alias AniminaWeb.Plugs.SetLocale

  def update(conn, %{"locale" => locale}) do
    if locale in SetLocale.supported_locales() do
      Gettext.put_locale(AniminaWeb.Gettext, locale)

      conn = put_session(conn, :locale, locale)

      # Update user's language preference in DB if logged in
      conn =
        if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
          user = conn.assigns.current_scope.user

          user
          |> Ecto.Changeset.change(language: locale)
          |> Animina.Repo.update()

          conn
        else
          conn
        end

      redirect_back(conn)
    else
      redirect_back(conn)
    end
  end

  def update(conn, _params) do
    redirect_back(conn)
  end

  defp redirect_back(conn) do
    redirect_to =
      case get_req_header(conn, "referer") do
        [referer | _] ->
          uri = URI.parse(referer)
          path = uri.path || "/"
          if uri.query, do: "#{path}?#{uri.query}", else: path

        _ ->
          "/"
      end

    redirect(conn, to: redirect_to)
  end
end
