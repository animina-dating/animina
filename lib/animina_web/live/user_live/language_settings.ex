defmodule AniminaWeb.UserLive.LanguageSettings do
  use AniminaWeb, :live_view

  import Plug.CSRFProtection, only: [get_csrf_token: 0]

  @languages [
    {"de", "DE", "🇩🇪", "Deutsch"},
    {"en", "EN", "🇬🇧", "English"},
    {"tr", "TR", "🇹🇷", "Türkçe"},
    {"ru", "RU", "🇷🇺", "Русский"},
    {"ar", "AR", "🇸🇦", "العربية"},
    {"pl", "PL", "🇵🇱", "Polski"},
    {"fr", "FR", "🇫🇷", "Français"},
    {"es", "ES", "🇪🇸", "Español"},
    {"uk", "UK", "🇺🇦", "Українська"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/users/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>{gettext("Language")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Language")}
            <:subtitle>{gettext("Choose your preferred language")}</:subtitle>
          </.header>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <%= for {code, _abbr, flag, name} <- @languages do %>
            <form action="/locale" method="post">
              <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
              <input type="hidden" name="locale" value={code} />
              <button
                type="submit"
                class={[
                  "flex items-center gap-3 w-full px-4 py-3 rounded-lg border transition-colors text-start",
                  if(code == @current_locale,
                    do: "border-primary bg-primary/10 text-primary font-medium",
                    else:
                      "border-base-300 text-base-content/70 hover:border-primary hover:text-primary"
                  )
                ]}
              >
                <span class="text-2xl">{flag}</span>
                <span class="text-sm">{name}</span>
              </button>
            </form>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_locale = Gettext.get_locale(AniminaWeb.Gettext)

    socket =
      socket
      |> assign(:page_title, gettext("Language"))
      |> assign(:languages, @languages)
      |> assign(:current_locale, current_locale)

    {:ok, socket}
  end
end
