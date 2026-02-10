defmodule AniminaWeb.LocaleController do
  use AniminaWeb, :controller

  alias AniminaWeb.Plugs.SetLocale
  import AniminaWeb.Helpers.ControllerHelpers, only: [redirect_back: 1]

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
end
