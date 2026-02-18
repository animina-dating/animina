defmodule AniminaWeb.UserLive.AccountSessions do
  use AniminaWeb, :live_view

  on_mount {AniminaWeb.UserAuth, {:require_sudo_mode, "/my/settings/account/sessions"}}

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.page_header
          title={gettext("Active Sessions")}
          subtitle={gettext("Manage your active login sessions")}
        >
          <:crumb navigate={~p"/my"}>{gettext("My Hub")}</:crumb>
          <:crumb navigate={~p"/my/settings"}>{gettext("Settings")}</:crumb>
          <:crumb navigate={~p"/my/settings/account"}>{gettext("Account & Security")}</:crumb>
        </.page_header>

        <.live_component
          module={AniminaWeb.AccountSessionsComponent}
          id="sessions"
          user={@user}
          sessions={@sessions}
          current_session_id={@current_session_id}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Accounts.list_user_sessions(user.id)
    current_token = socket.assigns.current_session_token

    current_session_id =
      Enum.find_value(sessions, fn s -> if s.token == current_token, do: s.id end)

    socket =
      socket
      |> assign(:page_title, gettext("Active Sessions"))
      |> assign(:user, user)
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
        AniminaWeb.UserAuth.disconnect_sessions([deleted_token])
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
    AniminaWeb.UserAuth.disconnect_sessions(deleted_tokens)

    sessions = Accounts.list_user_sessions(user.id)

    {:noreply,
     socket
     |> assign(:sessions, sessions)
     |> put_flash(:info, gettext("All other sessions have been logged out."))}
  end
end
