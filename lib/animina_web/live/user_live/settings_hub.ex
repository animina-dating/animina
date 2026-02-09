defmodule AniminaWeb.UserLive.SettingsHub do
  @moduledoc """
  Settings hub LiveView showing 4 category cards:
  Profile, Privacy & Blocking, Account & Security, Language.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts.ProfileCompleteness
  alias AniminaWeb.Languages

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("Settings")}
            <:subtitle>{gettext("Manage your account and app settings")}</:subtitle>
          </.header>
        </div>

        <div class="grid gap-3">
          <.settings_card
            navigate={~p"/settings/profile"}
            icon="hero-user"
            title={gettext("Profile")}
            preview={@profile_preview}
          />
          <.settings_card
            navigate={~p"/settings/privacy"}
            icon="hero-eye-slash"
            title={gettext("Privacy & Blocking")}
            preview={@privacy_preview}
          />
          <.settings_card
            navigate={~p"/settings/account"}
            icon="hero-shield-check"
            title={gettext("Account & Security")}
            preview={@user.email}
          />
          <.settings_card
            navigate={~p"/settings/language"}
            icon="hero-globe-alt"
            title={gettext("Language")}
            preview={@language_preview}
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

  defp settings_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="flex items-center gap-4 p-4 rounded-lg border border-base-300 hover:border-primary transition-colors"
    >
      <span class="flex-shrink-0 text-base-content/60">
        <.icon name={@icon} class="h-6 w-6" />
      </span>
      <div class="flex-1 min-w-0">
        <div class="font-semibold text-sm text-base-content">
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
    profile_completeness = ProfileCompleteness.compute(user)

    profile_preview =
      if profile_completeness.completed_count < profile_completeness.total_count do
        gettext("%{completed}/%{total} complete",
          completed: profile_completeness.completed_count,
          total: profile_completeness.total_count
        )
      else
        gettext("Profile complete")
      end

    socket =
      socket
      |> assign(:page_title, gettext("Settings"))
      |> assign(:user, user)
      |> assign(:language_preview, Languages.display_name(current_locale))
      |> assign(:privacy_preview, build_privacy_preview(user))
      |> assign(:profile_preview, profile_preview)

    {:ok, socket}
  end

  defp build_privacy_preview(user) do
    if user.hide_online_status do
      gettext("Online status hidden")
    else
      gettext("Online status visible")
    end
  end
end
