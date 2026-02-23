defmodule AniminaWeb.UserLive.PrivacySettings do
  @moduledoc """
  LiveView for managing privacy settings, including online status visibility.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.settings_header
          title={gettext("Privacy & Blocking")}
          subtitle={gettext("Manage your privacy settings")}
        />

        <div class="space-y-6">
          <div class="flex items-center justify-between p-4 rounded-lg border border-base-300">
            <div class="flex-1 mr-4">
              <div class="font-semibold text-sm text-base-content">
                {gettext("Online status visible")}
              </div>
              <div class="text-xs text-base-content/60 mt-1">
                {gettext(
                  "Other users can see when you are online, your last seen time, and your activity patterns."
                )}
              </div>
              <div class="text-xs text-base-content/40 mt-1">
                {gettext("Note: Admins and moderators can always see your online status.")}
              </div>
            </div>
            <div class="flex flex-col items-center gap-1">
              <input
                type="checkbox"
                class="toggle toggle-success"
                checked={!@hide_online_status}
                phx-click="toggle_online_status"
              />
              <span class={[
                "text-xs font-medium",
                if(!@hide_online_status, do: "text-success", else: "text-base-content/40")
              ]}>
                {if !@hide_online_status, do: gettext("On"), else: gettext("Off")}
              </span>
            </div>
          </div>

          <div class="flex items-center justify-between p-4 rounded-lg border border-base-300">
            <div class="flex-1 mr-4">
              <div class="font-semibold text-sm text-base-content">
                {gettext("Wingman")}
              </div>
              <div class="text-xs text-base-content/60 mt-1">
                {gettext("The AI Wingman suggests conversation starters when you open a new chat.")}
              </div>
            </div>
            <div class="flex flex-col items-center gap-1">
              <input
                type="checkbox"
                class="toggle toggle-success"
                checked={@wingman_enabled}
                phx-click="toggle_wingman"
              />
              <span class={[
                "text-xs font-medium",
                if(@wingman_enabled, do: "text-success", else: "text-base-content/40")
              ]}>
                {if @wingman_enabled, do: gettext("On"), else: gettext("Off")}
              </span>
            </div>
          </div>

          <.link
            navigate={~p"/my/settings/blocked-contacts"}
            class="flex items-center gap-4 p-4 rounded-lg border border-base-300 hover:border-primary transition-colors"
          >
            <span class="flex-shrink-0 text-base-content/60">
              <.icon name="hero-shield-check" class="h-6 w-6" />
            </span>
            <div class="flex-1 min-w-0">
              <div class="font-semibold text-sm text-base-content">
                {gettext("Blocked Contacts")}
              </div>
              <div class="text-xs text-base-content/60 truncate mt-0.5">
                {@blocked_contacts_preview}
              </div>
            </div>
            <span class="flex-shrink-0 text-base-content/30">
              <.icon name="hero-chevron-right-mini" class="h-5 w-5" />
            </span>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, gettext("Privacy & Blocking"))
      |> assign(:user, user)
      |> assign(:hide_online_status, user.hide_online_status)
      |> assign(:wingman_enabled, user.wingman_enabled)
      |> assign(:blocked_contacts_preview, build_blocked_contacts_preview(user))

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_online_status", _params, socket) do
    new_value = !socket.assigns.hide_online_status

    case Accounts.update_online_status_visibility(socket.assigns.user, %{
           hide_online_status: new_value
         }) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:hide_online_status, updated_user.hide_online_status)
         |> put_flash(
           :info,
           if(new_value,
             do: gettext("Online status is now hidden from other users."),
             else: gettext("Online status is now visible to other users.")
           )
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not update privacy settings."))}
    end
  end

  @impl true
  def handle_event("toggle_wingman", _params, socket) do
    new_value = !socket.assigns.wingman_enabled

    case Accounts.update_wingman_enabled(socket.assigns.user, %{wingman_enabled: new_value}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:wingman_enabled, updated_user.wingman_enabled)
         |> put_flash(
           :info,
           if(new_value,
             do: gettext("Wingman is now active."),
             else: gettext("Wingman is now inactive.")
           )
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not update privacy settings."))}
    end
  end

  defp build_blocked_contacts_preview(user) do
    count = Accounts.count_contact_blacklist_entries(user)

    case count do
      0 -> gettext("No contacts blocked")
      1 -> gettext("1 contact blocked")
      n -> gettext("%{count} contacts blocked", count: n)
    end
  end
end
