defmodule AniminaWeb.UserLive.SettingsHub do
  @moduledoc """
  Settings hub LiveView showing profile cards (with completeness) and
  settings cards on a single page, grouped under section headers.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
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

        <%!-- Profile section --%>
        <.section_heading title={gettext("Profile")} />

        <%= if @profile_completeness.completed_count < @profile_completeness.total_count do %>
          <div class="mb-4 p-4 rounded-lg bg-base-200/50">
            <div class="flex justify-between text-sm text-base-content/60 mb-2">
              <span>{gettext("Profile completeness")}</span>
              <span class="font-medium">
                {@profile_completeness.completed_count}/{@profile_completeness.total_count}
              </span>
            </div>
            <div class="w-full bg-base-300 rounded-full h-2">
              <div
                class="bg-primary h-2 rounded-full transition-all"
                style={"width: #{@profile_completeness.completed_count / @profile_completeness.total_count * 100}%"}
              />
            </div>
          </div>
        <% end %>

        <div class="grid gap-3 mb-8">
          <.hub_card
            navigate={~p"/my/settings/profile/photo"}
            icon="hero-camera"
            title={gettext("Profile Photo")}
            subtitle={gettext("Upload your main profile photo")}
          >
            <:trailing>
              <.completeness_icon complete={@profile_completeness.items.profile_photo} />
            </:trailing>
          </.hub_card>
          <.hub_card
            navigate={~p"/my/settings/profile/info"}
            icon="hero-user"
            title={gettext("Profile Info")}
            subtitle={gettext("Add your basic information")}
          >
            <:trailing>
              <.completeness_icon complete={@profile_completeness.items.profile_info} />
            </:trailing>
          </.hub_card>
          <.hub_card
            navigate={~p"/my/settings/profile/moodboard"}
            icon="hero-squares-2x2"
            title={gettext("My Moodboard")}
            subtitle={gettext("Create your visual profile")}
          >
            <:trailing>
              <.completeness_icon complete={@profile_completeness.items.moodboard} />
            </:trailing>
          </.hub_card>
          <.hub_card
            navigate={~p"/my/settings/profile/traits"}
            icon="hero-flag"
            title={gettext("My Flags")}
            subtitle={gettext("Set your personality flags")}
          >
            <:trailing>
              <.completeness_icon complete={@profile_completeness.items.flags} />
            </:trailing>
          </.hub_card>
          <.hub_card
            navigate={~p"/my/settings/profile/preferences"}
            icon="hero-heart"
            title={gettext("Partner Preferences")}
            subtitle={gettext("Define what you're looking for")}
          >
            <:trailing>
              <.completeness_icon complete={@profile_completeness.items.partner_preferences} />
            </:trailing>
          </.hub_card>
          <.hub_card
            navigate={~p"/my/settings/profile/locations"}
            icon="hero-map-pin"
            title={gettext("Locations")}
            subtitle={gettext("Set your location")}
          >
            <:trailing>
              <.completeness_icon complete={@profile_completeness.items.location} />
            </:trailing>
          </.hub_card>
        </div>

        <%!-- Settings section --%>
        <.section_heading title={gettext("Settings")} />

        <div class="grid gap-3">
          <.hub_card
            navigate={~p"/my/settings/privacy"}
            icon="hero-eye-slash"
            title={gettext("Privacy")}
            subtitle={@privacy_preview}
          />
          <.hub_card
            navigate={~p"/my/settings/blocked-contacts"}
            icon="hero-no-symbol"
            title={gettext("Blocked Contacts")}
            subtitle={@blocked_contacts_preview}
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
        </div>

        <%!-- Features section --%>
        <.section_heading title={gettext("Features")} class="mt-8" />

        <div class="space-y-3">
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
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :class, :string, default: nil

  defp section_heading(assigns) do
    ~H"""
    <h2 class={["text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3", @class]}>
      {@title}
    </h2>
    """
  end

  attr :complete, :boolean, required: true

  defp completeness_icon(assigns) do
    ~H"""
    <span class="flex-shrink-0">
      <%= if @complete do %>
        <.icon name="hero-check-circle-solid" class="h-6 w-6 text-success" />
      <% else %>
        <span class="inline-block h-6 w-6 rounded-full border-2 border-base-content/20" />
      <% end %>
    </span>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_locale = Gettext.get_locale(AniminaWeb.Gettext)
    profile_completeness = ProfileCompleteness.compute(user)

    socket =
      socket
      |> assign(:page_title, gettext("Settings"))
      |> assign(:user, user)
      |> assign(:profile_completeness, profile_completeness)
      |> assign(:language_preview, Languages.display_name(current_locale))
      |> assign(:privacy_preview, build_privacy_preview(user))
      |> assign(:blocked_contacts_preview, build_blocked_contacts_preview(user))
      |> assign(:wingman_enabled, user.wingman_enabled)

    {:ok, socket}
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
        {:noreply, put_flash(socket, :error, gettext("Could not update feature settings."))}
    end
  end

  defp build_privacy_preview(user) do
    if user.hide_online_status do
      gettext("Online status hidden")
    else
      gettext("Online status visible")
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
