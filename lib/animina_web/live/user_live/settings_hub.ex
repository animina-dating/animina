defmodule AniminaWeb.UserLive.SettingsHub do
  use AniminaWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="text-center mb-8">
          <.header>
            {gettext("Settings")}
            <:subtitle>{gettext("Manage your account and profile")}</:subtitle>
          </.header>
        </div>

        <div class="grid gap-4">
          <.link
            navigate={~p"/users/settings/profile"}
            class="block p-6 rounded-lg border border-base-300 hover:border-primary transition-colors"
          >
            <h3 class="text-lg font-semibold text-base-content">{gettext("Edit Profile")}</h3>
            <p class="text-sm text-base-content/70 mt-1">
              {gettext("Change your display name, height, occupation, and language")}
            </p>
          </.link>

          <.link
            navigate={~p"/users/settings/preferences"}
            class="block p-6 rounded-lg border border-base-300 hover:border-primary transition-colors"
          >
            <h3 class="text-lg font-semibold text-base-content">
              {gettext("Partner Preferences")}
            </h3>
            <p class="text-sm text-base-content/70 mt-1">
              {gettext("Update your partner preferences")}
            </p>
          </.link>

          <.link
            navigate={~p"/users/settings/locations"}
            class="block p-6 rounded-lg border border-base-300 hover:border-primary transition-colors"
          >
            <h3 class="text-lg font-semibold text-base-content">{gettext("Locations")}</h3>
            <p class="text-sm text-base-content/70 mt-1">
              {gettext("Manage your locations")}
            </p>
          </.link>

          <.link
            navigate={~p"/users/settings/account"}
            class="block p-6 rounded-lg border border-base-300 hover:border-primary transition-colors"
          >
            <h3 class="text-lg font-semibold text-base-content">{gettext("Account Security")}</h3>
            <p class="text-sm text-base-content/70 mt-1">
              {gettext("Change your email address and password")}
            </p>
          </.link>

          <.link
            navigate={~p"/users/settings/delete-account"}
            class="block p-6 rounded-lg border border-base-300 hover:border-error/50 transition-colors"
          >
            <h3 class="text-lg font-semibold text-error">{gettext("Delete Account")}</h3>
            <p class="text-sm text-base-content/70 mt-1">
              {gettext("Permanently delete your account and all associated data")}
            </p>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Settings"))}
  end
end
