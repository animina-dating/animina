defmodule AniminaWeb.UserLive.ProfileHub do
  @moduledoc """
  Profile hub LiveView showing profile-building categories:
  avatar, profile info, moodboard, flags, preferences, locations.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts.ProfileCompleteness

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.page_header
          title={gettext("My Profile")}
          subtitle={gettext("Build and manage your dating profile")}
        >
          <:crumb navigate={~p"/my"}>{gettext("My Hub")}</:crumb>
          <:crumb navigate={~p"/my/settings"}>{gettext("Settings")}</:crumb>
        </.page_header>

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

        <%!-- Section: My Profile --%>
        <.section_heading title={gettext("My Profile")} />

        <%!-- Progress Bar --%>
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
            <:trailing><.completeness_icon complete={@profile_completeness.items.flags} /></:trailing>
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
    profile_completeness = ProfileCompleteness.compute(user)

    socket =
      socket
      |> assign(:page_title, gettext("My Profile"))
      |> assign(:user, user)
      |> assign(:profile_completeness, profile_completeness)

    {:ok, socket}
  end
end
