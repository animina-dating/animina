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
        <.page_header
          title={gettext("Settings")}
          subtitle={gettext("Manage your account and app settings")}
        >
          <:crumb navigate={~p"/my"}>{gettext("My Hub")}</:crumb>
        </.page_header>

        <div class="grid gap-3">
          <.hub_card
            navigate={~p"/my/settings/profile"}
            icon="hero-user"
            title={gettext("Profile")}
            subtitle={@profile_preview}
          />
          <.hub_card
            navigate={~p"/my/settings/privacy"}
            icon="hero-eye-slash"
            title={gettext("Privacy & Blocking")}
            subtitle={@privacy_preview}
          />
          <.hub_card
            navigate={~p"/my/settings/account"}
            icon="hero-shield-check"
            title={gettext("Account & Security")}
            subtitle={@user.email}
          />
          <.hub_card
            navigate={~p"/my/settings/language"}
            icon="hero-globe-alt"
            title={gettext("Language")}
            subtitle={@language_preview}
          />
          <.hub_card
            navigate={~p"/my/settings/wingman"}
            icon="hero-light-bulb"
            title={gettext("Wingman Style")}
            subtitle={@wingman_preview}
          />
        </div>
      </div>
    </Layouts.app>
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
      |> assign(:wingman_preview, wingman_style_label(user.wingman_style || "casual"))

    {:ok, socket}
  end

  defp build_privacy_preview(user) do
    if user.hide_online_status do
      gettext("Online status hidden")
    else
      gettext("Online status visible")
    end
  end

  defp wingman_style_label("casual"), do: gettext("Casual")
  defp wingman_style_label("funny"), do: gettext("Funny")
  defp wingman_style_label("empathetic"), do: gettext("Empathetic")
  defp wingman_style_label(_), do: gettext("Casual")
end
