defmodule AniminaWeb.UserLive.AccountHub do
  @moduledoc """
  Account & Security hub LiveView showing 4 category cards:
  Email & Password, Passkeys, Sessions, Delete Account.
  """

  use AniminaWeb, :live_view

  on_mount {AniminaWeb.UserAuth, :require_sudo_mode}

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/my/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>{gettext("Account & Security")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Account & Security")}
            <:subtitle>
              {gettext("Manage your email, password, passkeys, sessions, and account")}
            </:subtitle>
          </.header>
        </div>

        <div class="grid gap-3">
          <.account_card
            navigate={~p"/my/settings/account/email-password"}
            icon="hero-envelope"
            title={gettext("Email & Password")}
            preview={@user.email}
          />
          <.account_card
            navigate={~p"/my/settings/account/passkeys"}
            icon="hero-finger-print"
            title={gettext("Passkeys")}
            preview={@passkey_preview}
          />
          <.account_card
            navigate={~p"/my/settings/account/sessions"}
            icon="hero-device-phone-mobile"
            title={gettext("Active Sessions")}
            preview={@session_preview}
          />
          <.account_card
            navigate={~p"/my/settings/account/delete"}
            icon="hero-trash"
            title={gettext("Delete Account")}
            preview={gettext("Permanently delete your account and data")}
            danger={true}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :preview, :string, default: nil
  attr :danger, :boolean, default: false

  defp account_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-4 p-4 rounded-lg border transition-colors",
        if(@danger,
          do: "border-error/30 hover:border-error",
          else: "border-base-300 hover:border-primary"
        )
      ]}
    >
      <span class={[
        "flex-shrink-0",
        if(@danger, do: "text-error/60", else: "text-base-content/60")
      ]}>
        <.icon name={@icon} class="h-6 w-6" />
      </span>
      <div class="flex-1 min-w-0">
        <div class={[
          "font-semibold text-sm",
          if(@danger, do: "text-error", else: "text-base-content")
        ]}>
          {@title}
        </div>
        <div :if={@preview} class="text-xs text-base-content/60 truncate mt-0.5">
          {@preview}
        </div>
      </div>
      <span class="flex-shrink-0 text-base-content/30">
        <.icon name="hero-chevron-right-mini" class="h-5 w-5" />
      </span>
    </.link>
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
