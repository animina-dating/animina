defmodule AniminaWeb.UserLive.SessionSettings do
  @moduledoc """
  LiveView for managing active sessions across devices.
  Users can see all active sessions and revoke individual ones
  or log out of all other devices.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias AniminaWeb.Helpers.UserAgentParser
  alias AniminaWeb.UserAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.settings_header
          title={gettext("Active Sessions")}
          subtitle={gettext("Manage your active sessions across devices")}
        />

        <div :if={length(@sessions) > 1} class="mb-6">
          <button
            phx-click="revoke_all_other"
            data-confirm={gettext("Log out of all other devices?")}
            class="btn btn-outline btn-sm btn-error"
          >
            {gettext("Log out all other devices")}
          </button>
        </div>

        <div class="space-y-3">
          <div
            :for={session <- @sessions}
            class={[
              "flex items-start gap-4 p-4 rounded-lg border",
              if(session.id == @current_session_id,
                do: "border-primary bg-primary/5",
                else: "border-base-300"
              )
            ]}
          >
            <span class="flex-shrink-0 mt-1 text-base-content/60">
              <.icon name={UserAgentParser.device_icon(session.user_agent)} class="h-6 w-6" />
            </span>

            <div class="flex-1 min-w-0">
              <div class="font-semibold text-sm text-base-content">
                {UserAgentParser.summary(session.user_agent)}
                <span
                  :if={session.id == @current_session_id}
                  class="badge badge-primary badge-sm ml-2"
                >
                  {gettext("This device")}
                </span>
              </div>

              <div class="text-xs text-base-content/60 mt-1 space-y-0.5">
                <div :if={session.ip_address}>
                  IP: {session.ip_address}
                </div>
                <div>
                  {gettext("Last active:")}
                  {format_time(session.last_seen_at || session.inserted_at)}
                </div>
                <div>
                  {gettext("Signed in:")}
                  {format_time(session.inserted_at)}
                </div>
              </div>
            </div>

            <div :if={session.id != @current_session_id} class="flex-shrink-0">
              <button
                phx-click="revoke_session"
                phx-value-id={session.id}
                data-confirm={gettext("Log out this session?")}
                class="btn btn-ghost btn-xs text-error"
              >
                {gettext("Log out")}
              </button>
            </div>
          </div>
        </div>

        <div :if={@sessions == []} class="text-center text-base-content/60 py-8">
          {gettext("No active sessions found.")}
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Accounts.list_user_sessions(user.id)
    current_token = socket.assigns.current_session_token

    # Find the current session's ID by matching the token
    current_session_id =
      Enum.find_value(sessions, fn s -> if s.token == current_token, do: s.id end)

    socket =
      socket
      |> assign(:page_title, gettext("Active Sessions"))
      |> assign(:sessions, sessions)
      |> assign(:current_session_id, current_session_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("revoke_session", %{"id" => token_id}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.delete_user_session_by_id(token_id, user.id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Session not found."))}

      deleted_token ->
        UserAuth.disconnect_sessions([deleted_token])
        sessions = Accounts.list_user_sessions(user.id)

        {:noreply,
         socket
         |> assign(:sessions, sessions)
         |> put_flash(:info, gettext("Session has been logged out."))}
    end
  end

  def handle_event("revoke_all_other", _params, socket) do
    user = socket.assigns.current_scope.user
    current_token = socket.assigns.current_session_token

    deleted_tokens = Accounts.delete_other_user_sessions(user.id, current_token)
    UserAuth.disconnect_sessions(deleted_tokens)

    sessions = Accounts.list_user_sessions(user.id)

    {:noreply,
     socket
     |> assign(:sessions, sessions)
     |> put_flash(:info, gettext("All other sessions have been logged out."))}
  end

  defp format_time(nil), do: "-"

  defp format_time(dt) do
    dt
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> Calendar.strftime("%d.%m.%Y %H:%M")
  end
end
