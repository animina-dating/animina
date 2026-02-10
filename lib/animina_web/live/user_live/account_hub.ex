defmodule AniminaWeb.UserLive.AccountHub do
  @moduledoc """
  Account & Security hub LiveView showing 4 category cards:
  Email & Password, Passkeys, Sessions, Delete Account.
  """

  use AniminaWeb, :live_view

  on_mount {AniminaWeb.UserAuth, {:require_sudo_mode, "/my/settings/account"}}

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.page_header
          title={gettext("Account & Security")}
          subtitle={gettext("Manage your email, password, passkeys, sessions, and account")}
        >
          <:crumb navigate={~p"/my/settings"}>{gettext("Settings")}</:crumb>
        </.page_header>

        <div class="grid gap-3">
          <.hub_card
            navigate={~p"/my/settings/account/email-password"}
            icon="hero-envelope"
            title={gettext("Email & Password")}
            subtitle={@user.email}
          />
          <.hub_card
            navigate={~p"/my/settings/account/passkeys"}
            icon="hero-finger-print"
            title={gettext("Passkeys")}
            subtitle={@passkey_preview}
          />
          <.hub_card
            navigate={~p"/my/settings/account/sessions"}
            icon="hero-device-phone-mobile"
            title={gettext("Active Sessions")}
            subtitle={@session_preview}
          />
          <.hub_card
            navigate={~p"/my/settings/account/delete"}
            icon="hero-trash"
            title={gettext("Delete Account")}
            subtitle={gettext("Permanently delete your account and data")}
            danger={true}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    passkeys = Accounts.list_user_passkeys(user)
    sessions = Accounts.list_user_sessions(user.id)

    passkey_preview =
      case length(passkeys) do
        0 -> gettext("No passkeys")
        1 -> gettext("1 passkey")
        n -> gettext("%{count} passkeys", count: n)
      end

    session_preview =
      case length(sessions) do
        1 -> gettext("1 active session")
        n -> gettext("%{count} active sessions", count: n)
      end

    socket =
      socket
      |> assign(:page_title, gettext("Account & Security"))
      |> assign(:user, user)
      |> assign(:passkey_preview, passkey_preview)
      |> assign(:session_preview, session_preview)

    {:ok, socket}
  end
end
