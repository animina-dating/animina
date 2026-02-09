defmodule AniminaWeb.UserLive.SettingsHub do
  @moduledoc """
  Unified settings hub LiveView showing both profile-building categories
  and account settings on a single page.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.ProfileCompleteness
  alias Animina.Emails
  alias AniminaWeb.Languages

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("My Profile & Settings")}
            <:subtitle>{gettext("Manage your profile and account settings")}</:subtitle>
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
    profile_completeness = ProfileCompleteness.compute(user)

    socket =
      socket
      |> assign(:page_title, gettext("My Profile & Settings"))
      |> assign(:user, user)
      |> assign(:profile_completeness, profile_completeness)
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
