defmodule AniminaWeb.UserLive.ProfileHub do
  @moduledoc """
  Profile hub LiveView showing profile-building categories with completion status.

  Displays the 6 profile items (photo, info, moodboard, flags, preferences, locations)
  with check/empty-circle indicators and a progress bar when not fully complete.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts.ProfileCompleteness

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("My Profile")}
            <:subtitle>{gettext("Build and complete your dating profile")}</:subtitle>
          </.header>
        </div>

        <%!-- Progress Bar --%>
        <%= if @profile_completeness.completed_count < @profile_completeness.total_count do %>
          <div class="mb-8 p-4 rounded-lg bg-base-200/50">
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

        <%!-- Profile Cards --%>
        <div class="grid gap-3">
          <.profile_card
            navigate={~p"/settings/avatar"}
            icon="hero-camera"
            title={gettext("Profile Photo")}
            description={gettext("Upload your main profile photo")}
            complete={@profile_completeness.items.profile_photo}
          />
          <.profile_card
            navigate={~p"/settings/profile"}
            icon="hero-user"
            title={gettext("Profile Info")}
            description={gettext("Add your basic information")}
            complete={@profile_completeness.items.profile_info}
          />
          <.profile_card
            navigate={~p"/settings/moodboard"}
            icon="hero-squares-2x2"
            title={gettext("My Moodboard")}
            description={gettext("Create your visual profile")}
            complete={@profile_completeness.items.moodboard}
          />
          <.profile_card
            navigate={~p"/settings/traits"}
            icon="hero-flag"
            title={gettext("My Flags")}
            description={gettext("Set your personality flags")}
            complete={@profile_completeness.items.flags}
          />
          <.profile_card
            navigate={~p"/settings/preferences"}
            icon="hero-heart"
            title={gettext("Partner Preferences")}
            description={gettext("Define what you're looking for")}
            complete={@profile_completeness.items.partner_preferences}
          />
          <.profile_card
            navigate={~p"/settings/locations"}
            icon="hero-map-pin"
            title={gettext("Locations")}
            description={gettext("Set your location")}
            complete={@profile_completeness.items.location}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :complete, :boolean, required: true

  defp profile_card(assigns) do
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
        <div class="text-xs text-base-content/60 truncate mt-0.5">
          {@description}
        </div>
      </div>
      <span class="flex-shrink-0">
        <%= if @complete do %>
          <.icon name="hero-check-circle-solid" class="h-6 w-6 text-success" />
        <% else %>
          <span class="inline-block h-6 w-6 rounded-full border-2 border-base-content/20" />
        <% end %>
      </span>
    </.link>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    profile_completeness = ProfileCompleteness.compute(user)

    socket =
      socket
      |> assign(:page_title, gettext("My Profile"))
      |> assign(:profile_completeness, profile_completeness)

    {:ok, socket}
  end
end
