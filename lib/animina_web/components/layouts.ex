defmodule AniminaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AniminaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :display_name, :string,
    default: nil,
    doc: "optional display name to show in navbar (e.g. during registration)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-base-100">
      <!-- Navigation -->
      <header class="fixed top-0 inset-x-0 z-50 bg-base-200/95 backdrop-blur-sm border-b border-base-300">
        <nav aria-label="Main" class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <a href="/" class="flex items-center gap-2 group">
              <span class="text-2xl font-light tracking-tight text-primary transition-colors group-hover:text-primary/80">
                ANIMINA
              </span>
            </a>

            <div class="flex items-center gap-4">
              <form action="/locale" method="post" class="flex items-center">
                <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                <select
                  name="locale"
                  onchange="this.form.submit()"
                  class="select select-ghost select-sm bg-transparent text-sm"
                  aria-label={gettext("Language")}
                >
                  <% current_locale = Gettext.get_locale(AniminaWeb.Gettext) %>
                  <option value="de" selected={current_locale == "de"}>🇩🇪 DE</option>
                  <option value="en" selected={current_locale == "en"}>🇬🇧 EN</option>
                  <option value="tr" selected={current_locale == "tr"}>🇹🇷 TR</option>
                  <option value="ru" selected={current_locale == "ru"}>🇷🇺 RU</option>
                  <option value="ar" selected={current_locale == "ar"}>🇸🇦 AR</option>
                  <option value="pl" selected={current_locale == "pl"}>🇵🇱 PL</option>
                  <option value="fr" selected={current_locale == "fr"}>🇫🇷 FR</option>
                  <option value="es" selected={current_locale == "es"}>🇪🇸 ES</option>
                  <option value="uk" selected={current_locale == "uk"}>🇺🇦 UK</option>
                </select>
              </form>
              <%= if @current_scope && !@display_name do %>
                <span class="text-base text-base-content/70">
                  {@current_scope.user.email}
                </span>
                <a
                  href="/users/settings"
                  class="text-base font-medium text-base-content/70 hover:text-primary transition-colors"
                >
                  {gettext("Settings")}
                </a>
                <.link
                  href="/users/log-out"
                  method="delete"
                  class="text-base font-medium text-base-content/70 hover:text-primary transition-colors"
                >
                  {gettext("Log out")}
                </.link>
              <% end %>
              <%= if @display_name do %>
                <!-- Profile Avatar with Dropdown (during registration wizard) -->
                <div class="relative">
                  <button
                    type="button"
                    id="profile-menu-button"
                    class="flex items-center gap-2 p-1 rounded-full opacity-100"
                    aria-label={gettext("Your profile")}
                    aria-haspopup="true"
                    phx-click={
                      JS.toggle(
                        to: "#profile-dropdown",
                        in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
                        out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
                      )
                    }
                  >
                    <div class="w-9 h-9 rounded-full border-2 flex items-center justify-center bg-secondary border-secondary">
                      <span class="text-sm font-semibold text-secondary-content">
                        {String.first(@display_name)}
                      </span>
                    </div>
                    <span class="text-sm font-medium text-base-content hidden sm:inline">
                      {@display_name}
                    </span>
                  </button>
                  <!-- Dropdown Menu -->
                  <div
                    id="profile-dropdown"
                    class="hidden absolute end-0 mt-2 w-48 rounded-lg bg-base-100 shadow-lg ring-1 ring-base-300 py-1 z-50"
                    phx-click-away={
                      JS.hide(
                        to: "#profile-dropdown",
                        transition:
                          {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
                      )
                    }
                  >
                    <.link
                      href="/users/log-out"
                      method="delete"
                      class="block w-full text-start px-4 py-2 text-sm text-base-content/70 hover:bg-base-200 hover:text-primary transition-colors"
                    >
                      {gettext("Log out")}
                    </.link>
                  </div>
                </div>
              <% end %>
              <%= if !@current_scope && !@display_name do %>
                <a
                  href="/users/log-in"
                  class="text-base font-medium text-base-content/70 hover:text-primary transition-colors"
                >
                  {gettext("Log in")}
                </a>
                <a
                  href="/users/register"
                  class="inline-flex items-center justify-center px-5 py-2 text-base font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
                >
                  {gettext("Register")}
                </a>
              <% end %>
            </div>
          </div>
        </nav>
      </header>
      <!-- Flash Messages -->
      <div class="fixed top-16 inset-x-0 z-40 pointer-events-none">
        <.flash_group flash={@flash} />
      </div>
      <!-- Main Content -->
      <main class="flex-1 pt-16">
        {render_slot(@inner_block)}
      </main>
      <!-- Footer -->
      <footer class="border-t border-base-300 bg-base-200/50">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
          <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div class="flex items-center gap-2">
              <span class="text-xl font-light tracking-tight text-primary">ANIMINA</span>
            </div>
            <nav
              aria-label="Footer"
              class="flex flex-wrap justify-center gap-6 text-base text-base-content/70"
            >
              <a href="#" class="hover:text-primary transition-colors">{gettext("About us")}</a>
              <a href="#" class="hover:text-primary transition-colors">{gettext("Privacy")}</a>
              <a href="#" class="hover:text-primary transition-colors">{gettext("Terms")}</a>
              <a href="#" class="hover:text-primary transition-colors">{gettext("Imprint")}</a>
              <a
                href="https://github.com/animina-dating/animina"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:text-primary transition-colors"
              >
                GitHub
              </a>
            </nav>
            <p class="text-base text-base-content/70">
              &copy; {DateTime.utc_now().year} ANIMINA v{Animina.version()}. Open Source mit ❤️
            </p>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} auto_dismiss={true} />
      <.flash kind={:error} flash={@flash} auto_dismiss={true} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ms-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ms-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 start-0 [[data-theme=light]_&]:start-1/3 [[data-theme=dark]_&]:start-2/3 transition-[inset-inline-start]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
