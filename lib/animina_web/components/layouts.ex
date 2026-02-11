defmodule AniminaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AniminaWeb, :html

  alias Animina.Accounts.ProfileCompleteness
  alias Animina.Accounts.Scope
  alias Animina.Photos
  alias Animina.TimeMachine
  alias AniminaWeb.Languages

  @dev Application.compile_env(:animina, :dev_routes)

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

  attr :full_width, :boolean,
    default: false,
    doc: "if true, skip the default max-w-7xl container around inner_block content"

  slot :inner_block, required: true

  def app(assigns) do
    avatar_url =
      if assigns[:current_scope] && assigns.current_scope.user do
        Photos.get_user_avatar_url(assigns.current_scope.user.id)
      end

    profile_completeness =
      if assigns[:current_scope] && assigns.current_scope.user do
        ProfileCompleteness.compute(assigns.current_scope.user)
      end

    assigns =
      assigns
      |> assign(:avatar_url, avatar_url)
      |> assign(:profile_completeness, profile_completeness)
      |> assign(:languages, Languages.all())
      |> assign(:dev, @dev)

    ~H"""
    <div class="min-h-screen flex flex-col bg-base-100">
      <%= if @current_scope && Scope.admin?(@current_scope) do %>
        <div class={"fixed inset-0 z-[100] border-4 border-red-500 pointer-events-none#{if @dev, do: " border-dashed"}"} />
      <% end %>
      <%= if @current_scope && !Scope.admin?(@current_scope) && Scope.moderator?(@current_scope) do %>
        <div class={"fixed inset-0 z-[100] border-4 border-yellow-400 pointer-events-none#{if @dev, do: " border-dashed"}"} />
      <% end %>
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
              <% current_locale = Gettext.get_locale(AniminaWeb.Gettext) %>
              <% {_code, current_abbr, current_flag, _name} =
                Enum.find(@languages, fn {code, _, _, _} -> code == current_locale end) %>
              <%= if !@current_scope || @display_name do %>
                <div class="hidden sm:block relative">
                  <button
                    type="button"
                    id="language-menu-button"
                    class="flex items-center gap-1 p-2 rounded-lg hover:bg-base-300 transition-colors"
                    aria-label={gettext("Change language")}
                    aria-haspopup="true"
                    phx-click={
                      JS.toggle(
                        to: "#language-dropdown",
                        in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
                        out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
                      )
                      |> JS.hide(
                        to: "#profile-dropdown",
                        transition:
                          {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
                      )
                    }
                  >
                    <.icon name="hero-globe-alt" class="size-5 text-base-content/70" />
                    <span class="hidden sm:inline text-sm font-medium text-base-content/70">
                      {current_flag} {current_abbr}
                    </span>
                  </button>

                  <div
                    id="language-dropdown"
                    class="hidden absolute end-0 mt-2 w-48 rounded-lg bg-base-100 shadow-lg ring-1 ring-base-300 py-1 z-50"
                    phx-click-away={
                      JS.hide(
                        to: "#language-dropdown",
                        transition:
                          {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
                      )
                    }
                  >
                    <div class="px-4 py-2 border-b border-base-300">
                      <p class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                        {gettext("Language")}
                      </p>
                    </div>
                    <%= for {code, _abbr, flag, name} <- @languages do %>
                      <form action="/locale" method="post">
                        <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                        <input type="hidden" name="locale" value={code} />
                        <button
                          type="submit"
                          class={[
                            "block w-full text-start px-4 py-2 text-sm transition-colors",
                            if(code == current_locale,
                              do: "bg-primary/10 text-primary font-medium",
                              else: "text-base-content/70 hover:bg-base-200 hover:text-primary"
                            )
                          ]}
                        >
                          {flag} {name}
                        </button>
                      </form>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%= if @current_scope && !@display_name do %>
                <%= if Scope.admin?(@current_scope) do %>
                  <.live_component
                    module={AniminaWeb.LiveOnlineCountComponent}
                    id="online-count"
                    user_id={@current_scope.user.id}
                  />
                <% end %>
                <div class={if Scope.admin?(@current_scope), do: "hidden sm:block"}>
                  <.live_component
                    module={AniminaWeb.LiveUnreadBadgeComponent}
                    id="unread-badge"
                    user_id={@current_scope.user.id}
                  />
                </div>
                <div class="relative">
                  <button
                    type="button"
                    id="user-menu-button"
                    class="flex items-center gap-2 p-1 rounded-full"
                    aria-label={gettext("Your profile")}
                    aria-haspopup="true"
                    phx-click={
                      JS.toggle(
                        to: "#user-dropdown",
                        in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
                        out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
                      )
                    }
                  >
                    <div class="relative">
                      <div class="w-9 h-9 rounded-full border-2 border-primary overflow-hidden flex items-center justify-center bg-primary">
                        <%= if @avatar_url do %>
                          <img
                            src={@avatar_url}
                            alt=""
                            class="w-full h-full object-cover"
                          />
                        <% else %>
                          <span class="text-sm font-semibold text-primary-content">
                            {String.first(
                              @current_scope.user.display_name || @current_scope.user.email
                            )}
                          </span>
                        <% end %>
                      </div>
                      <%= if @current_scope.user.state == "waitlisted" do %>
                        <span
                          class="absolute -top-0.5 -end-0.5 w-3 h-3 bg-amber-500 border-2 border-base-200 rounded-full"
                          title={gettext("On waitlist")}
                        />
                      <% end %>
                    </div>
                    <span class="text-sm font-medium text-base-content truncate max-w-20 sm:max-w-32">
                      {@current_scope.user.display_name || @current_scope.user.email}
                    </span>
                    <%= if Scope.admin?(@current_scope) do %>
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
                        {gettext("Admin")}
                      </span>
                    <% end %>
                    <%= if !Scope.admin?(@current_scope) && Scope.moderator?(@current_scope) do %>
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                        {gettext("Moderator")}
                      </span>
                    <% end %>
                  </button>

                  <div
                    id="user-dropdown"
                    class="hidden absolute end-0 mt-2 w-56 rounded-lg bg-base-100 shadow-lg ring-1 ring-base-300 py-1 z-50"
                    phx-click-away={
                      JS.hide(
                        to: "#user-dropdown",
                        transition:
                          {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
                      )
                    }
                  >
                    <!-- User Info -->
                    <div class="px-4 py-2 border-b border-base-300">
                      <p class="text-sm font-medium text-base-content truncate">
                        {@current_scope.user.display_name}
                      </p>
                      <p class="text-xs text-base-content/50 truncate">
                        {@current_scope.user.email}
                      </p>
                    </div>
                    <!-- Waitlist Banner (only shown in user role) -->
                    <%= if @current_scope.user.state == "waitlisted" && @current_scope.current_role == "user" do %>
                      <a
                        href="/my/waitlist"
                        class="waitlist-badge block px-4 py-2 bg-amber-50 border-b border-base-300 hover:bg-amber-100 transition-colors"
                      >
                        <div class="flex items-center gap-2">
                          <span class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-amber-500 text-white text-xs font-bold">
                            <.icon name="hero-clock-micro" class="size-3" />
                          </span>
                          <span class="text-sm font-medium text-amber-800">
                            {gettext("On Waitlist")}
                          </span>
                        </div>
                      </a>
                    <% end %>
                    <!-- My Hub -->
                    <a
                      href="/my"
                      class="block px-4 py-2 text-sm text-base-content/70 hover:bg-base-200 hover:text-primary transition-colors"
                    >
                      {gettext("My Hub")}
                    </a>
                    <!-- Settings -->
                    <a
                      href="/my/settings"
                      class="block px-4 py-2 text-sm text-base-content/70 hover:bg-base-200 hover:text-primary transition-colors"
                    >
                      {gettext("Settings")}
                    </a>
                    <!-- App Section (hidden while on waitlist) -->
                    <div
                      :if={@current_scope.user.state != "waitlisted"}
                      class="border-t border-base-300 mt-1"
                    >
                      <div class="px-4 py-1.5 pt-2">
                        <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                          {gettext("App")}
                        </p>
                      </div>
                      <a
                        href="/my/spotlight"
                        class="block px-4 py-2 text-sm text-base-content/70 hover:bg-base-200 hover:text-primary transition-colors"
                      >
                        {gettext("Spotlight")}
                      </a>
                      <a
                        href="/my/messages"
                        class="block px-4 py-2 text-sm text-base-content/70 hover:bg-base-200 hover:text-primary transition-colors"
                      >
                        {gettext("Messages")}
                      </a>
                    </div>
                    <!-- Administration (admin only) -->
                    <%= if Scope.has_role?(@current_scope, "admin") do %>
                      <div class="border-t border-base-300 mt-1">
                        <a
                          href="/admin"
                          class="block px-4 py-2 text-sm text-base-content/70 hover:bg-base-200 hover:text-primary transition-colors"
                        >
                          {gettext("Administration")}
                        </a>
                      </div>
                    <% end %>
                    <!-- Time Travel (dev only) -->
                    <%= if @dev do %>
                      <div class="border-t border-amber-300 mt-1 bg-amber-50/50">
                        <div class="px-4 py-1.5 pt-2">
                          <p class="text-xs font-semibold text-amber-600 uppercase tracking-wider">
                            Time Travel
                          </p>
                        </div>
                        <div class="px-4 py-1 text-xs text-amber-700">
                          {TimeMachine.virtual_now()}
                        </div>
                        <%= if TimeMachine.format_offset() do %>
                          <div class="px-4 py-0.5 text-xs font-mono font-medium text-amber-800">
                            {TimeMachine.format_offset()}
                          </div>
                        <% end %>
                        <div class="flex gap-1 px-4 py-2">
                          <form action="/dev/time-travel/add-hours" method="post" class="inline">
                            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                            <input type="hidden" name="hours" value="1" />
                            <button
                              type="submit"
                              class="px-2 py-1 text-xs font-medium rounded bg-amber-200 text-amber-800 hover:bg-amber-300 transition-colors"
                            >
                              +1h
                            </button>
                          </form>
                          <form action="/dev/time-travel/add-days" method="post" class="inline">
                            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                            <input type="hidden" name="days" value="1" />
                            <button
                              type="submit"
                              class="px-2 py-1 text-xs font-medium rounded bg-amber-200 text-amber-800 hover:bg-amber-300 transition-colors"
                            >
                              +1d
                            </button>
                          </form>
                          <form action="/dev/time-travel/reset" method="post" class="inline">
                            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                            <button
                              type="submit"
                              class="px-2 py-1 text-xs font-medium rounded bg-amber-100 text-amber-700 hover:bg-amber-200 transition-colors"
                            >
                              Reset
                            </button>
                          </form>
                        </div>
                      </div>
                    <% end %>
                    <!-- Logout -->
                    <div class="border-t border-base-300 mt-1">
                      <.link
                        href="/users/log-out"
                        method="delete"
                        class="block w-full text-start px-4 py-2 text-sm text-base-content/70 hover:bg-base-200 hover:text-primary transition-colors"
                      >
                        {gettext("Log out")}
                      </.link>
                    </div>
                  </div>
                </div>
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
                      |> JS.hide(
                        to: "#language-dropdown",
                        transition:
                          {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
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
                    <div class="border-b border-base-300 px-2 py-2">
                      <p class="px-2 pb-1 text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                        {gettext("Language")}
                      </p>
                      <div class="grid grid-cols-3 gap-1">
                        <%= for {code, _abbr, flag, _name} <- @languages do %>
                          <form action="/locale" method="post">
                            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                            <input type="hidden" name="locale" value={code} />
                            <button
                              type="submit"
                              class={[
                                "flex items-center justify-center w-full px-2 py-1.5 rounded text-sm transition-colors",
                                if(code == current_locale,
                                  do: "bg-primary/10 text-primary font-medium",
                                  else: "text-base-content/70 hover:bg-base-200"
                                )
                              ]}
                            >
                              {flag}
                            </button>
                          </form>
                        <% end %>
                      </div>
                    </div>
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
        <div :if={!@full_width} class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
          {render_slot(@inner_block)}
        </div>
        <div :if={@full_width}>
          {render_slot(@inner_block)}
        </div>
      </main>
      <!-- Footer -->
      <footer class="border-t border-base-300 bg-base-200/50">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
          <div class="flex flex-col items-center gap-4">
            <div class="flex items-center gap-2">
              <span class="text-xl font-light tracking-tight text-primary">ANIMINA</span>
            </div>
            <nav
              aria-label="Footer"
              class="flex flex-wrap justify-center gap-6 text-base text-base-content/70"
            >
              <a href="/datenschutz" class="hover:text-primary transition-colors">
                {gettext("Privacy")}
              </a>
              <a href="/agb" class="hover:text-primary transition-colors">
                {gettext("Terms of Service")}
              </a>
              <a href="/impressum" class="hover:text-primary transition-colors">
                {gettext("Imprint")}
              </a>
              <a
                href="https://github.com/animina-dating/animina"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:text-primary transition-colors"
              >
                GitHub
              </a>
              <a
                href="https://github.com/animina-dating/animina/issues/new?template=bug_report.yml"
                onclick="window.open('https://github.com/animina-dating/animina/issues/new?template=bug_report.yml&page_url=' + encodeURIComponent(window.location.href), '_blank'); return false;"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:text-primary transition-colors"
              >
                {gettext("Report bug")}
              </a>
            </nav>
            <div class="flex flex-wrap justify-center gap-3 text-sm">
              <%= for {code, abbr, flag, _name} <- @languages do %>
                <form action="/locale" method="post" class="inline">
                  <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                  <input type="hidden" name="locale" value={code} />
                  <button
                    type="submit"
                    id={"footer-lang-#{code}"}
                    class={[
                      "transition-colors",
                      if(code == current_locale,
                        do: "text-primary font-medium",
                        else: "text-base-content/70 hover:text-primary"
                      )
                    ]}
                  >
                    {flag} {abbr}
                  </button>
                </form>
              <% end %>
            </div>
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
        id="deployment-notice"
        kind={:info}
        title={gettext("Updating ANIMINA")}
        phx-disconnected={
          show(".phx-server-error #deployment-notice") |> JS.remove_attribute("hidden")
        }
        phx-connected={hide("#deployment-notice") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext(
          "A new software version is being installed on the server. This will only take a moment..."
        )}
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
