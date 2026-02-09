defmodule AniminaWeb.UserLive.SettingsHub do
  @moduledoc """
  Settings hub LiveView showing account settings categories.

  Profile-building features (Moodboard, Flags, Partner Preferences, etc.)
  are accessible directly from the navigation dropdown. This page focuses
  on account administration only.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Emails
  alias AniminaWeb.Languages

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("Account")}
            <:subtitle>{gettext("Manage your account settings")}</:subtitle>
          </.header>
        </div>

        <%!-- Profile Summary --%>
        <div class="flex items-center gap-4 mb-8 p-4 rounded-lg bg-base-200/50">
          <div class="flex-shrink-0 w-14 h-14 rounded-full bg-primary text-primary-content flex items-center justify-center text-xl font-bold">
            {String.first(@user.display_name)}
          </div>
          <div>
            <div class="font-semibold text-base-content">{@user.display_name}</div>
            <div class="text-sm text-base-content/60">{@user.email}</div>
          </div>
        </div>

        <%!-- Section: App --%>
        <.section_heading title={gettext("App")} />

        <div class="grid gap-3 mb-8">
          <.settings_card
            navigate={~p"/settings/language"}
            icon="hero-globe-alt"
            title={gettext("Language")}
            preview={@language_preview}
          />
        </div>

        <%!-- Section: Privacy --%>
        <.section_heading title={gettext("Privacy")} />

        <div class="grid gap-3 mb-8">
          <.settings_card
            navigate={~p"/settings/privacy"}
            icon="hero-eye-slash"
            title={gettext("Privacy")}
            preview={@privacy_preview}
          />
        </div>

        <%!-- Section: History --%>
        <.section_heading title={gettext("History")} />

        <div class="grid gap-3 mb-8">
          <.settings_card
            navigate={~p"/settings/emails"}
            icon="hero-envelope"
            title={gettext("Email History")}
            preview={@email_logs_preview}
          />
        </div>

        <%!-- Section: Account --%>
        <.section_heading title={gettext("Account")} />

        <div class="grid gap-3 mb-8">
          <.settings_card
            navigate={~p"/settings/account"}
            icon="hero-shield-check"
            title={gettext("Account Security")}
            preview={@user.email}
          />
          <.settings_card
            navigate={~p"/settings/passkeys"}
            icon="hero-finger-print"
            title={gettext("Passkeys")}
            preview={@passkeys_preview}
          />
          <.settings_card
            navigate={~p"/settings/sessions"}
            icon="hero-computer-desktop"
            title={gettext("Active Sessions")}
            preview={@sessions_preview}
          />
          <.settings_card
            navigate={~p"/settings/delete-account"}
            icon="hero-trash"
            title={gettext("Delete Account")}
            preview={gettext("Permanently delete your account")}
            variant={:danger}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true

  defp section_heading(assigns) do
    ~H"""
    <h2 class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
      {@title}
    </h2>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :preview, :string, default: nil
  attr :variant, :atom, default: :default

  defp settings_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-4 p-4 rounded-lg border transition-colors",
        if(@variant == :danger,
          do: "border-base-300 hover:border-error/50",
          else: "border-base-300 hover:border-primary"
        )
      ]}
    >
      <span class={[
        "flex-shrink-0",
        if(@variant == :danger, do: "text-error", else: "text-base-content/60")
      ]}>
        <.icon name={@icon} class="h-6 w-6" />
      </span>
      <div class="flex-1 min-w-0">
        <div class={[
          "font-semibold text-sm",
          if(@variant == :danger, do: "text-error", else: "text-base-content")
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
    current_locale = Gettext.get_locale(AniminaWeb.Gettext)

    socket =
      socket
      |> assign(:page_title, gettext("Account"))
      |> assign(:user, user)
      |> assign(:language_preview, Languages.display_name(current_locale))
      |> assign(:passkeys_preview, build_passkeys_preview(user))
      |> assign(:sessions_preview, build_sessions_preview(user))
      |> assign(:privacy_preview, build_privacy_preview(user))
      |> assign(:email_logs_preview, build_email_logs_preview(user))

    {:ok, socket}
  end

  defp build_privacy_preview(user) do
    if user.hide_online_status do
      gettext("Online status hidden")
    else
      gettext("Online status visible")
    end
  end

  defp build_email_logs_preview(user) do
    count = Emails.count_email_logs_for_user(user.id)

    case count do
      0 -> gettext("No emails sent")
      1 -> gettext("1 email sent")
      n -> gettext("%{count} emails sent", count: n)
    end
  end

  defp build_sessions_preview(user) do
    count = length(Accounts.list_user_sessions(user.id))

    case count do
      0 -> gettext("No active sessions")
      1 -> gettext("1 active session")
      n -> gettext("%{count} active sessions", count: n)
    end
  end

  defp build_passkeys_preview(user) do
    count = length(Accounts.list_user_passkeys(user))

    case count do
      0 -> gettext("No passkeys")
      1 -> gettext("1 passkey")
      n -> gettext("%{count} passkeys", count: n)
    end
  end
end
